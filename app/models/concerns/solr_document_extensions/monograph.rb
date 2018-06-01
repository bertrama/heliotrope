# frozen_string_literal: true

module SolrDocumentExtensions::Monograph
  extend ActiveSupport::Concern

  def creator_display
    Array(self[Solrizer.solr_name('creator_display', :stored_searchable)]).first
  end

  def buy_url
    Array(self[Solrizer.solr_name('buy_url', :symbol)])
  end

  def creator_full_name
    Array(self[Solrizer.solr_name('creator_full_name', :stored_searchable)]).first
  end

  def isbn
    Array(self[Solrizer.solr_name('isbn', :stored_searchable)])
  end

  def press
    Array(self[Solrizer.solr_name('press', :stored_searchable)]).first
  end

  def representative_manifest_id
    Array(self[Solrizer.solr_name('representative_manifest_id', :symbol)]).first
  end

  def section_titles
    value = Array(self[Solrizer.solr_name('section_titles', :symbol)]).first
    value.present? ? value.split(/\r?\n/).reject(&:blank?) : value
  end

  def location
    Array(self[Solrizer.solr_name('location', :stored_searchable)]).first
  end

  def series
    Array(self[Solrizer.solr_name('series', :stored_searchable)])
  end
end
