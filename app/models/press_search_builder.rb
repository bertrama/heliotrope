# frozen_string_literal: true

class PressSearchBuilder < ::SearchBuilder
  self.default_processor_chain += [:filter_by_press]

  def filter_by_press(solr_parameters)
    solr_parameters[:fq] ||= []
    children = Press.find_by(subdomain: blacklight_params['press']).children.pluck(:subdomain)
    all_presses = children.push(blacklight_params['press']).uniq
    solr_parameters[:fq] << "{!terms f=press_sim}#{all_presses.map(&:downcase).join(',')}"
  end
end
