# frozen_string_literal: true

# The persistent identifier table ships as a generator, so the host test app has not
# run it. Create it here so model specs have something to talk to.
#
# Kept in sync by hand with
# lib/generators/hyrax/doi/templates/db/migrate/create_hyrax_doi_persistent_identifiers.rb.erb
RSpec.configure do |config|
  config.before(:suite) do
    connection = ActiveRecord::Base.connection
    next if connection.table_exists?(:hyrax_doi_persistent_identifiers)

    connection.create_table :hyrax_doi_persistent_identifiers do |t|
      t.string :resource_id
      t.string :resource_type
      t.string :scheme, null: false
      t.string :provider, null: false
      t.string :value, null: false
      t.string :state
      t.string :origin, null: false, default: 'minted'
      t.boolean :primary, null: false, default: true
      t.datetime :minted_at
      t.datetime :last_synced_at
      t.text :last_error
      t.timestamps
    end

    connection.add_index :hyrax_doi_persistent_identifiers,
                         %i[scheme provider value],
                         unique: true,
                         name: 'index_hyrax_doi_pids_on_scheme_provider_value'
    connection.add_index :hyrax_doi_persistent_identifiers,
                         %i[resource_id scheme],
                         name: 'index_hyrax_doi_pids_on_resource_id_and_scheme'
  end
end
