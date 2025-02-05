# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  describe '#new' do
    subject { get :new }

    context 'user signed in' do
      before { allow_any_instance_of(described_class).to receive(:user_signed_in?).and_return(true) }

      it do
        is_expected.to redirect_to root_path(locale: 'en')
        expect(cookies[:fulcrum_signed_in_static]).not_to be nil
      end

      context 'stored location for user' do
        before { allow_any_instance_of(described_class).to receive(:stored_location_for).with(:user).and_return('http://return_to_me') }

        it { is_expected.to redirect_to 'http://return_to_me' }
      end
    end

    context 'user not signed in' do
      before { allow_any_instance_of(described_class).to receive(:user_signed_in?).and_return(false) }

      it { is_expected.to redirect_to new_authentications_path }
    end
  end

  describe '#shib_session' do
    subject { get :shib_session, params: { resource: resource } }

    let(:resource) { prefix + path }
    let(:prefix) { '' }
    let(:path) { '' }
    let(:target) { '/' + path }

    before { allow_any_instance_of(described_class).to receive(:authenticate_user!) }

    it { is_expected.to redirect_to target }

    context 'path' do
      let(:path) { 'concern/noid' }

      it { is_expected.to redirect_to target }

      context 'root' do
        let(:prefix) { '/' }

        it { is_expected.to redirect_to target }
      end

      context 'http' do
        let(:prefix) { 'HtTp://anything you want between the slashes/' }

        it { is_expected.to redirect_to target }
      end

      context 'https' do
        let(:prefix) { 'HtTpS://everything up to the slash/' }

        it { is_expected.to redirect_to target }
      end
    end
  end

  describe '#destroy' do
    subject { get :destroy }

    before do
      cookies[:fulcrum_signed_in_static] = true
      allow_any_instance_of(described_class).to receive(:user_signed_in?).and_return(true)
    end

    it do
      expect(ENV).to receive(:[]=).with('FAKE_HTTP_X_REMOTE_USER', '(null)')
      is_expected.to redirect_to root_url
      expect(cookies[:fulcrum_signed_in_static]).to be nil
    end
  end

  describe '#discovery_feed' do
    it 'gets full discovery feed' do
      Greensub::Institution.create!(identifier: '1', name: 'University of Michigan', site: 'Site', login: 'Login', entity_id: 'https://shibboleth.umich.edu/idp/shibboleth')
      Greensub::Institution.create!(identifier: '2', name: 'College', site: 'Site', login: 'Login', entity_id: 'https://shibboleth.college.edu/idp/shibboleth')
      get :discovery_feed
      expect(response).to be_success
      expect { JSON.parse response.body }.not_to raise_error
      expect(JSON.parse(response.body).size).to be > 1
    end
  end

  describe '#discovery_feed/id' do
    let(:monograph) do
      create(:public_monograph) do |m|
        m.ordered_members << file_set
        m.save!
        file_set.save!
        m
      end
    end
    let(:file_set) { create(:public_file_set) }

    before { clear_grants_table }

    it 'gets parameterized discovery feed' do
      m = Sighrax.factory(monograph.id)
      component = Greensub::Component.create!(identifier: m.resource_token, name: m.title, noid: m.noid)
      institution1 = Greensub::Institution.create!(identifier: '1', name: 'University of Michigan', site: 'Site', login: 'Login', entity_id: 'https://shibboleth.umich.edu/idp/shibboleth')
      # To show that this institution is not used
      institution2 = Greensub::Institution.create!(identifier: '2', name: 'College', site: 'Site', login: 'Login', entity_id: 'https://shibboleth.college.edu/idp/shibboleth') # rubocop:disable Lint/UselessAssignment
      product = Greensub::Product.create!(identifier: 'product', name: 'name', purchase: 'purchase')
      product.components << component
      product.save!
      Greensub.subscribe(subscriber: institution1, target: product)
      get :discovery_feed, params: { id: file_set.id }
      expect(response).to have_http_status(:success)
      expect { JSON.parse response.body }.not_to raise_error
      expect(JSON.parse(response.body).size).to be(1)
      expect(JSON.parse(response.body)[0]['entityID']).to eq('https://shibboleth.umich.edu/idp/shibboleth')
    end

    it 'gets empty discovery feed if given bogus id' do
      Greensub::Institution.create!(identifier: '1', name: 'University of Michigan', site: 'Site', login: 'Login', entity_id: 'https://shibboleth.umich.edu/idp/shibboleth')
      Greensub::Institution.create!(identifier: '2', name: 'College', site: 'Site', login: 'Login', entity_id: 'https://shibboleth.college.edu/idp/shibboleth')
      get :discovery_feed, params: { id: 'bogus_id' }
      expect(response).to have_http_status(:success)
      expect { JSON.parse response.body }.not_to raise_error
      expect(JSON.parse(response.body).size).to be 0
    end
  end
end
