# frozen_string_literal: true

require 'rails_helper'

# called by #should_render_facet?
def should_render_field?(_facet_config, _display_facet)
  true
end

RSpec.describe FacetHelper do
  describe '#should_render_facet?' do
    let(:blacklight_config) { double("blacklight_config") }
    let(:display_facet) { double("display_facet") }
    let(:items) { double("items") }

    before do
      allow(blacklight_config).to receive(:facet_configuration_for_field).and_return(nil)
      allow(display_facet).to receive(:name).and_return(nil)
      allow(display_facet).to receive(:items).and_return(items)
    end

    context 'items empty' do
      let(:items) { [] }

      it do
        rvalue = should_render_facet?(display_facet)
        expect(rvalue).to be false
        expect(items).to be_empty
      end
    end

    context 'three items' do
      let(:items) {
        [Blacklight::Solr::Response::Facets::FacetItem.new("a"),
         Blacklight::Solr::Response::Facets::FacetItem.new("b"),
         Blacklight::Solr::Response::Facets::FacetItem.new("c")]
      }

      it do
        rvalue = should_render_facet?(display_facet)
        expect(rvalue).to be true
        expect(items.count).to eq 3
      end
    end

    context 'three items with one blank' do
      let(:items) {
        [Blacklight::Solr::Response::Facets::FacetItem.new("a"),
         Blacklight::Solr::Response::Facets::FacetItem.new(""),
         Blacklight::Solr::Response::Facets::FacetItem.new("c")]
      }

      it do
        rvalue = should_render_facet?(display_facet)
        expect(rvalue).to be true
        expect(items.count).to eq 2
      end
    end

    context 'three items with two blank' do
      let(:items) {
        [Blacklight::Solr::Response::Facets::FacetItem.new(""),
         Blacklight::Solr::Response::Facets::FacetItem.new("b"),
         Blacklight::Solr::Response::Facets::FacetItem.new("")]
      }

      it do
        rvalue = should_render_facet?(display_facet)
        expect(rvalue).to be true
        expect(items.count).to eq 1
      end
    end

    context 'three items with all blank' do
      let(:items) {
        [Blacklight::Solr::Response::Facets::FacetItem.new(""),
         Blacklight::Solr::Response::Facets::FacetItem.new(""),
         Blacklight::Solr::Response::Facets::FacetItem.new("")]
      }

      it do
        rvalue = should_render_facet?(display_facet)
        expect(rvalue).to be false
        expect(items).to be_empty
      end
    end
  end

  describe "#should_collapse_facet?" do
    let(:facet_field) { Blacklight::Configuration::FacetField.new(field: "field").normalize! }

    # If blacklight changes how the collapse method works,
    # we want to detect that change.
    it 'responds to collapse method' do
      expect(facet_field.respond_to?(:collapse)).to be true
    end

    it 'not in params and not collapse' do
      allow(helper).to receive(:facet_field_in_params?).and_return(false)
      facet_field.collapse = false
      expect(helper.should_collapse_facet?(facet_field)).to be false
    end

    it 'not in params and collapse' do
      allow(helper).to receive(:facet_field_in_params?).and_return(false)
      facet_field.collapse = true
      expect(helper.should_collapse_facet?(facet_field)).to be true
    end

    it 'in params and not collapse' do
      allow(helper).to receive(:facet_field_in_params?).and_return(true)
      facet_field.collapse = false
      expect(helper.should_collapse_facet?(facet_field)).to be false
    end

    it 'in params and collapse' do
      allow(helper).to receive(:facet_field_in_params?).and_return(true)
      facet_field.collapse = true
      expect(helper.should_collapse_facet?(facet_field)).to be false
    end
  end

  describe "#facet_field_in_params?" do
    let(:facet_field) { Blacklight::Configuration::FacetField.new(field: "field").normalize! }

    ##
    # Get the values of the facet set in the blacklight query string
    # def facet_params field
    #   config = facet_configuration_for_field(field)
    #   params[:f][config.key] if params[:f]
    # end

    # @param [String] field Solr facet name
    # @return [Blacklight::Configuration::FacetField] Blacklight facet configuration for the solr field
    # def facet_configuration_for_field(field)
    #   # short-circuit on the common case, where the solr field name and the blacklight field name are the same.
    #   return facet_fields[field] if facet_fields[field] && facet_fields[field].field == field
    #
    #   # Find the facet field configuration for the solr field, or provide a default.
    #   facet_fields.values.find { |v| v.field.to_s == field.to_s } ||
    #       FacetField.new(field: field).normalize!
    # end

    it 'field is a String and NOT in params' do
      allow(helper).to receive(:facet_params).and_return(nil)
      expect(helper.facet_field_in_params?("String")).to be false
    end

    it 'field is a String and in params' do
      allow(helper).to receive(:facet_params) do |facet|
        Blacklight::Configuration::FacetField.new(field: facet).normalize!
      end
      expect(helper.facet_field_in_params?("String")).to be true
    end

    it 'field is a Symbol and NOT in params' do
      allow(helper).to receive(:facet_params).and_return(nil)
      expect(helper.facet_field_in_params?(:Symbol)).to be false
    end

    it 'field is a Symbol and in params' do
      allow(helper).to receive(:facet_params) do |facet|
        Blacklight::Configuration::FacetField.new(field: facet).normalize!
      end
      expect(helper.facet_field_in_params?(:Symbol)).to be true
    end

    it 'field is a FacetField without pivot and NOT in params' do
      allow(helper).to receive(:facet_params).and_return(nil)
      expect(helper.facet_field_in_params?(facet_field)).to be false
    end

    it 'field is a FacetField without pivot and in params' do
      allow(helper).to receive(:facet_params) do |field|
        Blacklight::Configuration::FacetField.new(field: field).normalize!
      end
      expect(helper.facet_field_in_params?(facet_field)).to be true
    end

    it 'field is a FacetField with pivot and NOT in params and pivot NOT in params' do
      facet_field[:pivot] = ["pivot"]
      allow(helper).to receive(:facet_params).and_return(nil)
      expect(helper.facet_field_in_params?(facet_field)).to be false
    end

    it 'field is a FacetField with pivot and NOT in params and pivot in params' do
      facet_field[:pivot] = ["pivot"]
      allow(helper).to receive(:facet_params) do |field|
        field == "pivot" ? Blacklight::Configuration::FacetField.new(field: field).normalize! : nil
      end
      expect(helper.facet_field_in_params?(facet_field)).to be true
    end

    it 'field is a FacetField with pivot and in params and pivot NOT in params' do
      facet_field[:pivot] = ["pivot"]
      allow(helper).to receive(:facet_params) do |field|
        field == "field" ? Blacklight::Configuration::FacetField.new(field: field).normalize! : nil
      end
      expect(helper.facet_field_in_params?(facet_field)).to be false
    end

    it 'field is a FacetField with pivot and in params and pivot in params' do
      facet_field[:pivot] = ["pivot"]
      allow(helper).to receive(:facet_params) do |field|
        Blacklight::Configuration::FacetField.new(field: field).normalize!
      end
      expect(helper.facet_field_in_params?(facet_field)).to be true
    end
  end
end
