# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "PDF EBooks", type: :request do
  describe "GET /ebooks/:id/download" do
    subject { get download_ebook_path(noid) }

    let(:actor) { instance_double(Anonymous) }
    let(:noid) { 'validnoid' }
    let(:entity) { instance_double(Sighrax::Entity, noid: noid, data: {}, valid?: true, title: 'title') }
    let(:policy) { instance_double(EntityPolicy, download?: download) }
    let(:download) { false }
    let(:press) { instance_double(Press, name: 'name') }
    let(:press_policy) { instance_double(PressPolicy, watermark_download?: watermark_download) }
    let(:watermark_download) { false }

    before do
      allow(Sighrax).to receive(:factory).with(noid).and_return(entity)
      allow(Sighrax).to receive(:policy).with(anything, entity).and_return(policy)
      allow(Sighrax).to receive(:press).with(entity).and_return(press)
      allow(PressPolicy).to receive(:new).with(anything, press).and_return(press_policy)
    end

    it do
      expect { subject }.not_to raise_error
      expect(response).to have_http_status(:unauthorized)
      expect(response).to render_template('hyrax/base/unauthorized')
    end

    context 'download?' do
      let(:download) { true }

      it do
        expect { subject }.not_to raise_error
        expect(response).to have_http_status(:found)
        expect(response).to redirect_to(hyrax.download_path(noid))
      end

      context 'watermarkable?' do
        before { allow(Sighrax).to receive(:watermarkable?).with(entity).and_return(true) }

        it do
          expect { subject }.not_to raise_error
          expect(response).to have_http_status(:found)
          expect(response).to redirect_to(hyrax.download_path(noid))
        end

        context 'watermark_download?' do
          let(:watermark_download) { true }
          let(:entity) do
            instance_double(
              Sighrax::Asset,
              noid: noid,
              data: {},
              valid?: true,
              parent: parent,
              title: 'title',
              resource_token: 'resource_token',
              media_type: 'application/pdf',
              filename: 'clippath.pdf'
            )
          end
          let(:parent) { instance_double(Sighrax::Entity, title: 'title') }
          let(:presenter) { instance_double(Hyrax::MonographPresenter, creator_display: 'creator', title: 'title', date_created: ['created'], publisher: ['publisher']) }

          before do
            allow(Sighrax).to receive(:hyrax_presenter).with(parent).and_return(presenter)
            allow(entity).to receive(:content).and_return(File.read(Rails.root.join(fixture_path, entity.filename)))
          end

          it do
            expect { subject }.not_to raise_error
            expect(response).to have_http_status(:ok)
            expect(response.body).not_to be_empty
            expect(response.body).not_to eq File.read(Rails.root.join(fixture_path, entity.filename))
            expect(response.header['Content-Type']).to eq(entity.media_type)
            expect(response.header['Content-Disposition']).to eq("attachment; filename=\"#{entity.filename}\"")
          end
        end
      end
    end
  end
end
