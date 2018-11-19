# frozen_string_literal: true

require 'rails_helper'
require 'import'
require 'export'

describe Import::Importer do
  let(:public_vis) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC }
  let(:private_vis) { Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE }

  let(:root_dir) { File.join(fixture_path, 'csv', 'import_sections') }
  let(:user) { create(:user, email: 'blah@example.com') }
  # let(:user_email) { '' }
  let(:press) { create(:press, subdomain: 'umich') }
  let(:importer) {
    described_class.new(root_dir: root_dir,
                        user_email: user.email,
                        press: press.subdomain,
                        visibility: public_vis,
                        monograph_id: monograph_id,
                        quiet: true,
                        workflow: 'my_workflow')
  }
  let(:monograph_id) { '' }
  let(:visibility) { public_vis }

  before do
    # Don't print status messages during specs
    allow($stdout).to receive(:puts)
  end

  describe 'initializer' do
    it 'has a root directory' do
      expect(importer.root_dir).to eq root_dir
    end

    it 'has a user' do
      expect(importer.user_email).to eq user.email
    end

    it 'has a press' do
      expect(importer.press_subdomain).to eq press.subdomain
    end

    it 'has a visibility' do
      expect(importer.visibility).to eq public_vis
    end

    it 'has quiet (which will turn off interactivity)' do
      expect(importer.quiet).to eq true
    end

    context 'default visibility' do
      let(:importer) { described_class.new(root_dir: root_dir, user_email: user.email, press: press.subdomain) }

      it 'is private' do
        expect(importer.visibility).to eq private_vis
      end
    end
  end

  describe '#import' do
    subject { importer.import(manifest) }

    let(:manifest) { double('manifest') }

    context 'default no monograph' do
      it { is_expected.to be false }
    end

    context 'with ldp:gone-ish or monograph not found' do
      let(:monograph_id) { 'validnoid' }

      it { expect { subject }.to raise_error(/No monograph found with id '#{monograph_id}'/) }
    end

    context 'with monograph' do
      let(:monograph) { build(:monograph, representative_id: cover.id) }
      let(:cover) { create(:file_set) }
      let(:file1) { create(:file_set) }
      let(:file2) { create(:file_set) }
      let(:expected_manifest) do
        <<~eos
          NOID,File Name,Link,Title,Resource Type,External Resource URL,Caption,Alternative Text,Copyright Holder,Copyright Status,Open Access?,Funder,Allow High-Res Display?,Allow Download?,Rights Granted,CC License,Permissions Expiration Date,After Expiration: Allow Display?,After Expiration: Allow Download?,Credit Line,Holding Contact,Exclusive to Fulcrum,Identifier(s),Content Type,Creator(s),Additional Creator(s),Creator Display,Sort Date,Display Date,Description,Publisher,Subject,ISBN(s),Buy Book URL,Pub Year,Pub Location,Series,Keywords,Section,Language,Transcript,Translation,DOI,Handle,Redirect to,Representative Kind
          instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder,instruction placeholder
          #{cover.id},,"=HYPERLINK(""#{Rails.application.routes.url_helpers.hyrax_file_set_url(cover)}"")",#{cover.title.first},#{cover.resource_type.first},,,,,,,,,,,,,,,,,,,,,,,#{cover.sort_date},,,,,,,,,,,,,,,,,,
          #{file1.id},,"=HYPERLINK(""#{Rails.application.routes.url_helpers.hyrax_file_set_url(file1)}"")",#{file1.title.first},pdf,,,,,,,,,,,,,,,,,,,,,,,#{file1.sort_date},,,,,,,,,,,,,,,,,,pdf_ebook
          #{file2.id},,"=HYPERLINK(""#{Rails.application.routes.url_helpers.hyrax_file_set_url(file2)}"")",NEW FILE TITLE,image,no,,,,,,,,,,,,,,,,,,,,,,2000-01-01,,,,,,,,,,,,,,,,,,cover
          #{monograph.id},://:MONOGRAPH://:,"=HYPERLINK(""#{Rails.application.routes.url_helpers.hyrax_monograph_url(monograph)}"")",NEW MONOGRAPH TITLE,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,://:MONOGRAPH://:,,,,,,,
        eos
      end
      let(:monograph_id) { monograph.id }
      let(:manifest) { expected_manifest }

      before do
        monograph.ordered_members << cover
        monograph.ordered_members << file1
        monograph.ordered_members << file2
        monograph.save!
      end

      after { FeaturedRepresentative.destroy_all }

      it do
        is_expected.to be true

        # import made file1 into a `pdf_ebook` representative
        expect(FeaturedRepresentative.count).to eq(1)
        expect(FeaturedRepresentative.where(monograph_id: monograph.id, kind: 'pdf_ebook').first.file_set_id).to eq(file1.id)

        # import made file2 into the cover
        m = Monograph.find(monograph_id)
        expect(m.representative_id).to eq(file2.id)
        expect(m.thumbnail_id).to eq(file2.id)

        # subsequent export equals what was just imported
        actual_manifest = Export::Exporter.new(monograph_id).export
        expect(actual_manifest).to eq expected_manifest
      end
    end
  end

  describe '#run' do
    let(:workflow_name) { 'my_workflow' }
    let(:admin_set) { create(:admin_set, edit_users: [user.user_key]) }
    let(:one_step_workflow) do
      {
        workflows: [
          {
            name: workflow_name,
            label: "One-step mediated deposit workflow",
            description: "A single-step workflow for mediated deposit",
            actions: [
              {
                name: "deposit", from_states: [], transition_to: "pending_review"
              }, {
                name: "approve", from_states: [{ names: ["pending_review"], roles: ["approving"] }],
                transition_to: "deposited",
                methods: ["Hyrax::Workflow::ActivateObject"]
              }, {
                name: "leave_a_comment", from_states: [{ names: ["pending_review"], roles: ["approving"] }]
              }
            ]
          }
        ]
      }
    end
    let(:workflow) { Sipity::Workflow.find_by!(name: workflow_name, permission_template: permission_template) }
    let(:permission_template) { create(:permission_template, admin_set_id: admin_set.id) }

    before do
      stub_out_redis
      Hyrax::Workflow::WorkflowImporter.generate_from_hash(data: one_step_workflow, permission_template: permission_template)
      permission_template.available_workflows.first.update!(active: true)
      Hyrax::Workflow::PermissionGenerator.call(roles: 'approving', workflow: workflow, agents: user)
    end

    context 'when the importer runs successfully' do
      # It saves a nice chunk of time (> 10 secs) to test the "reimport" here as well. Ugly though.
      it 'imports the new monograph and files, or "reimports" them to a pre-existing monograph' do
        expect { importer.run }
          .to change(Monograph, :count)
          .by(1)
          .and(change(FileSet, :count)
          .by(9))

        monograph = Monograph.first

        expect(monograph.id.length).not_to eq 36 # GUID
        expect(monograph.id.length).to eq 9 # NOID

        expect(monograph.depositor).to eq user.email
        expect(monograph.admin_set_id).to eq admin_set.id

        expect(monograph.visibility).to eq public_vis
        file_sets = monograph.ordered_members.to_a

        expect(file_sets[0].title).to eq ['Monograph Shipwreck']
        expect(file_sets[0].depositor).to eq user.email

        # The monograph cover/representative is the first file_set
        expect(file_sets[0].id).to eq monograph.representative_id

        expect(file_sets[0].license).to eq ['https://creativecommons.org/licenses/by-sa/4.0/']

        expect(file_sets[1].title).to eq ['Monograph Miranda']
        expect(file_sets[1].external_resource_url).to eq nil
        expect(file_sets[1].license).to eq ['http://creativecommons.org/publicdomain/mark/1.0/']
        expect(file_sets[1].exclusive_to_platform).to eq 'yes'

        expect(file_sets[2].title).to eq ['日本語のファイル']

        # FileSets w/ sections
        expect(file_sets[3].title).to eq ['Section 1 Shipwreck']
        expect(file_sets[3].section_title).to eq ['Act 1: Calm Waters']

        expect(file_sets[4].title).to eq ['Section 1 Miranda']
        expect(file_sets[4].section_title).to eq ['Act 1: Calm Waters']

        expect(file_sets[5].title).to eq ['Section 2 Shipwreck']
        expect(file_sets[5].section_title).to eq ['Act 2: Stirrin\' Up']

        # filesets should have the same visibility as the parent monograph
        expect(file_sets[0].visibility).to eq monograph.visibility
        expect(file_sets[8].visibility).to eq monograph.visibility

        # ******************************************************
        # *************** Start "reimport" tests ***************
        # ******************************************************

        reimporter = described_class.new(root_dir: root_dir, user_email: user.email, monograph_id: monograph.id)
        expect { reimporter.run }
          .to change(Monograph, :count)
          .by(0)
          .and(change(FileSet, :count)
          .by(9))

        # check it's indeed the same monograph
        expect(Monograph.first.id).to eq monograph.id

        # check counts explicitly
        expect(Monograph.count).to eq(1)
        expect(FileSet.count).to eq(18)

        # grab all FileSets again
        file_sets = Monograph.first.ordered_members.to_a

        # The monograph cover/representative is still the first file_set
        expect(file_sets[0].id).to eq monograph.representative_id

        # check order/existence of new files
        expect(file_sets[9].title).to eq ['Monograph Shipwreck']
        expect(file_sets[10].title).to eq ['Monograph Miranda']
        expect(file_sets[11].title).to eq ['日本語のファイル']
        expect(file_sets[12].title).to eq ['Section 1 Shipwreck']
        expect(file_sets[13].title).to eq ['Section 1 Miranda']
        expect(file_sets[14].title).to eq ['Section 2 Shipwreck']
        expect(file_sets[15].title).to eq ['Section 2 Miranda']
        expect(file_sets[16].title).to eq ['Previous Shipwreck File (Again)']
        expect(file_sets[17].title).to eq ['External Bard Transcript']

        # check monograph visibility doesn't change
        expect(Monograph.first.visibility).to eq monograph.visibility

        # old filesets should have the same visibility as the parent monograph
        expect(file_sets[0].visibility).to eq monograph.visibility
        expect(file_sets[8].visibility).to eq monograph.visibility

        # new filesets should have the same visibility as the parent monograph
        expect(file_sets[10].visibility).to eq monograph.visibility
        expect(file_sets[15].visibility).to eq monograph.visibility
      end
    end

    context 'when the monograph id doesn\'t match a pre-existing monograph' do
      let(:monograph_id) { 'non-existent' }
      let(:reimporter) { described_class.new(root_dir: root_dir, user_email: user.email, monograph_id: monograph_id) }

      it 'raises an exception' do
        expect { reimporter.run }.to raise_error(/No monograph found with id '#{monograph_id}'/)
      end
    end

    context 'when the user_email doesn\'t match a pre-existing user' do
      let(:email_address) { 'non-existent' }
      let(:importer) { described_class.new(root_dir: root_dir, user_email: email_address, press: press.subdomain) }

      it 'raises an exception' do
        expect { importer.run }.to raise_error(/No user found with email '#{email_address}'/)
      end
    end

    context 'when the root directory doesnt exist' do
      let(:root_dir) { File.join(fixture_path, 'bad_directory') }

      it 'raises an exception' do
        expect { importer.run }.to raise_error(/Directory not found/)
      end
    end

    context 'when the press is invalid' do
      let(:press) { Press.new(subdomain: 'incorrect press') }

      it 'raises an exception' do
        expect { importer.run }.to raise_error(/No press found with subdomain: 'incorrect press'/)
      end
    end

    context "when the workflow doesn't have an admin_set" do
      let(:importer) {
        described_class.new(root_dir: root_dir,
                            user_email: user.email,
                            press: press.subdomain,
                            visibility: public_vis,
                            monograph_id: monograph_id,
                            workflow: 'not_a_real_workflow')
      }

      it 'raises an exception' do
        expect { importer.run }.to raise_error(/a corresponding AdminSet was not found. Make sure you've registered this workflow./)
      end
    end
  end
end
