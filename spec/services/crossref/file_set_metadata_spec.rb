# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Crossref::FileSetMetadata do
  let(:monograph) do
    ::SolrDocument.new(id: '999999999',
                       has_model_ssim: ['Monograph'],
                       title_tesim: ['A Title'],
                       creator_tesim: ["Last, First\nSecondLast, SecondFirst"],
                       importable_creator_ss: "Last, First; SecondLast, SecondFirst",
                       press_tesim: [press.subdomain],
                       isbn_tesim: ["1234567890 (ebook)", "0987654321 (hardcover)"],
                       date_created_tesim: ['9999'],
                       doi_ssim: ['10.9985/blue.999999999'],
                       ordered_member_ids_ssim: ['111111111', '222222222', '333333333', '444444444', '555555555'],
                       member_ids_ssim: ['111111111', '222222222', '333333333', '444444444', '555555555'],
                       hasRelatedMediaFragment_ssim: ['555555555'])
  end

  let(:fs1) do
    ::SolrDocument.new(id: '111111111',
                       has_model_ssim: ['FileSet'],
                       monograph_id_ssim: '999999999',
                       title_tesim: ["FS 1"],
                       creator_tesim: ["Last, First"],
                       contributor_tesim: ["First Last", "A Place", "Actor, An (actor)"],
                       description_tesim: ["FS 1 Description"],
                       mime_type_ssi: "image/jpg")
  end

  let(:fs2) do
    ::SolrDocument.new(id: '222222222',
                       has_model_ssim: ['FileSet'],
                       monograph_id_ssim: '999999999',
                       title_tesim: ["FS 2"],
                       creator_tesim: ["Last, First"],
                       contributor_tesim: ["First Last", "A Place", "Actor, An (actor)"],
                       description_tesim: ["FS 2 Description"],
                       mime_type_ssi: "image/jpg")
  end

  let(:fs3) do
    ::SolrDocument.new(id: '333333333',
                       has_model_ssim: ['FileSet'],
                       monograph_id_ssim: '999999999',
                       title_tesim: ["FS 3"],
                       creator_tesim: ["Last, First"],
                       contributor_tesim: ["First Last", "A Place", "Actor, An (actor)"],
                       caption_tesim: ["FS 3 Caption"],
                       mime_type_ssi: "image/jpg")
  end

  # will be skipped: no dois for epubs
  let(:fs4) do
    ::SolrDocument.new(id: '444444444',
                       has_model_ssim: ['FileSet'],
                       monograph_id_ssim: '999999999',
                       title_tesim: ["EPUB"],
                       mime_type_ssi: "epub")
  end

  # will be skipped, no dois for covers
  let(:fs5) do
    ::SolrDocument.new(id: '555555555',
                       has_model_ssim: ['FileSet'],
                       monograph_id_ssim: '999999999',
                       title_tesim: ["Cover"],
                       mime_type_ssi: "image/jpg")
  end

  before do
    ActiveFedora::SolrService.add([monograph.to_h, fs1.to_h, fs2.to_h, fs3.to_h, fs4.to_h, fs5.to_h])
    ActiveFedora::SolrService.commit
    FeaturedRepresentative.create(work_id: '999999999', file_set_id: '444444444', kind: 'epub')
  end

  describe "#new" do
    context "when the Press cannot register DOIs" do
      let(:press) { create(:press, subdomain: "blue", name: "The Blue Press") }

      it "raises an error" do
        expect { described_class.new('999999999') }.to raise_error("Press blue can not make automatic DOIs")
      end
    end
  end

  describe "#build" do
    subject { described_class.new('999999999').build }

    let(:press) { create(:press, subdomain: "blue", name: "The Blue Press", doi_creation: true) }
    let(:timestamp) { "20190419111616" }

    before do
      allow_any_instance_of(described_class).to receive(:timestamp).and_return(timestamp)
      allow(BatchSaveJob).to receive_messages(perform_later: nil, perform_now: nil)
    end

    it "returns the doi submission doc with the correct data" do
      subject.remove_namespaces!

      expect(subject.at_css('doi_batch_id').content).to eq "#{press.subdomain}-#{monograph.id}-filesets-#{timestamp}"
      expect(subject.at_css('timestamp').content).to eq timestamp
      expect(subject.at_css('sa_component').attribute('parent_doi').value).to eq monograph.doi

      expect(described_class.new('999999999').presenters.length).to eq 5
      # no DOIs for covers, epubs (or mobi or pdf_ebook)
      expect(subject.xpath("//component_list/component").length).to eq 3

      [fs1, fs2, fs3].each_with_index do |fs, i|
        # See HELIO-2739 for names in description
        names = "Last, First. First Last, A Place, Actor, An (actor)."

        expect(subject.xpath("//component_list/component")[i].at_css('title').content).to eq fs.title.first
        if i == 2
          expect(subject.xpath("//component_list/component")[i].at_css('description').content).to eq fs.caption.first + " #{names}"
        else
          expect(subject.xpath("//component_list/component")[i].at_css('description').content).to eq fs.description.first + " #{names}"
        end
        expect(subject.xpath("//component_list/component")[i].at_css('format').attribute('mime_type').value).to eq fs.mime_type
        expect(subject.xpath("//component_list/component")[i].at_css('doi').content).to eq "#{monograph.doi}.cmp.#{i + 1}"
        expect(subject.xpath("//component_list/component")[i].at_css('resource').content).to eq "https://hdl.handle.net/2027/fulcrum.#{fs.id}"
      end
    end
  end
end
