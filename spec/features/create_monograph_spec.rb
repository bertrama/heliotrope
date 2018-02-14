# frozen_string_literal: true

require 'rails_helper'

feature 'Create a monograph' do
  context 'a logged in user' do
    let(:user) { create(:platform_admin) }
    let!(:press) { create(:press) }

    before do
      cosign_login_as user
      stub_out_redis
    end

    scenario do
      visit new_hyrax_monograph_path
      fill_in 'monograph[title][]', with: 'Test monograph'
      fill_in 'Author (last name)', with: 'Johns'
      fill_in 'Author (first name)', with: 'Jimmy'
      fill_in 'Additional Authors', with: 'Sub Way'
      fill_in 'Authorship Display (free-form text)', with: 'Fancy Authorship Name Stuff That Takes Precedence'
      select press.name, from: 'Publisher'
      fill_in 'ISBN (Hardcover)', with: '123-456-7890'
      click_button 'Save'

      expect(page).to have_content 'Test monograph'
      expect(page).to have_content "Fancy Authorship Name Stuff That Takes Precedence"
      expect(page).to_not have_content "Jimmy Johns and Sub Way"
      expect(page).to have_content "Your files are being processed by Fulcrum in the background."
    end
  end
end
