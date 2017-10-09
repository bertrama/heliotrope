# frozen_string_literal: true

require 'nokogiri'
require_dependency 'e_pub'

class EPubsSearchService
  attr_reader :epub

  def initialize(id)
    EPubsServiceJob.perform_now(id) unless File.directory? EPubsService.epub_path(id)
    @epub = EPub::Publication.from(id)
  end

  def find_selection(node, query)
    matches = []
    offset = 0

    while node.content.downcase.index(query.downcase, offset)
      cfi = EPub::Cfi.from(node, query, offset)
      matches.push(
        cfi: cfi.cfi,
        snippet: cfi.snippet
      )
      offset = cfi.pos1 + 1
    end
    matches
  end

  def find_targets(node, query)
    targets = []
    return nil unless node.content.downcase.index(query.downcase)

    node.children.each do |child|
      targets << if child.text? && child.text.downcase.index(query.downcase)
                   find_selection(child, query)
                 else
                   find_targets(child, query)
                 end
    end
    targets.compact
  end

  def results_from_chapters(db_results, query)
    results = {}
    results[:q] = query
    results[:search_results] = [] if db_results.length.positive?

    db_results.each do |chapter|
      file = File.join(EPubsService.epub_path(@epub.id), File.dirname(@epub.content_file), chapter[:href])
      doc = Nokogiri::XML(File.open(file))
      doc.remove_namespaces!

      matches = []
      body = doc.xpath("//body")
      body.children.each do |node|
        matches << find_targets(node, query)
      end

      matches.flatten.compact.each do |match|
        results[:search_results].push(
          cfi: "#{chapter[:basecfi]}#{match[:cfi]}",
          title: chapter[:title],
          snippet: match[:snippet]
        )
      end
    end
    results
  end

  def search(query)
    db_results = EPub::SqlLite.from(@epub).search_chapters(query)
    results_from_chapters(db_results, query)
  end
end
