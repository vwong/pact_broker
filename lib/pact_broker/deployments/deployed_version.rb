require "pact_broker/repositories/helpers"
require "pact_broker/deployments/currently_deployed_version_id"

module PactBroker
  module Deployments
    class DeployedVersion < Sequel::Model
      many_to_one :version, :class => "PactBroker::Domain::Version", :key => :version_id, :primary_key => :id
      many_to_one :environment, :class => "PactBroker::Deployments::Environment", :key => :environment_id, :primary_key => :id
      one_to_one :currently_deployed_version_id, :class => "PactBroker::Deployments::CurrentlyDeployedVersionId", key: :deployed_version_id, primary_key: :id

      plugin :timestamps, update_on_create: true
      plugin :insert_ignore, identifying_columns: [:pacticipant_id, :version_id, :environment_id, :target_for_index]

      dataset_module do
        include PactBroker::Repositories::Helpers

        def last_deployed_version(pacticipant, environment)
          currently_deployed
            .where(pacticipant_id: pacticipant.id)
            .where(environment: environment)
            .order(Sequel.desc(:created_at), Sequel.desc(:id))
            .first
        end

        def currently_deployed
          where(id: CurrentlyDeployedVersionId.select(:deployed_version_id))
        end

        def undeployed
          exclude(undeployed_at: nil)
        end

        def for_version_and_environment_and_target(version, environment, target)
          for_version_and_environment(version, environment).for_target(target)
        end

        def for_target(target)
          where(target: target)
        end

        def for_environment_name(environment_name)
          where(environment_id: db[:environments].select(:id).where(name: environment_name))
        end

        def for_pacticipant_name(pacticipant_name)
          where(pacticipant_id: db[:pacticipants].select(:id).where(name_like(:name, pacticipant_name)))
        end

        def for_version_and_environment(version, environment)
          where(version_id: version.id, environment_id: environment.id)
        end

        def for_environment(environment)
          where(environment_id: environment.id)
        end

        def order_by_date_desc
          order(Sequel.desc(:created_at), Sequel.desc(:id))
        end

        def record_undeployed
          where(undeployed_at: nil).update(undeployed_at: Sequel.datetime_class.now)
        end
      end

      def before_validation
        super
        self.target_for_index = target.nil? ? "" : target
      end

      def after_create
        super
        CurrentlyDeployedVersionId.new(
          pacticipant_id: pacticipant_id,
          environment_id: environment_id,
          version_id: version_id,
          target_for_index: target_for_index,
          deployed_version_id: id
        ).upsert
      end

      def currently_deployed
        !!currently_deployed_version_id
      end

      def version_number
        version.number
      end

      def record_undeployed
        self.class.where(id: id).record_undeployed
        self.refresh
      end
    end
  end
end

# Table: deployed_versions
# Columns:
#  id               | integer                     | PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY
#  uuid             | text                        | NOT NULL
#  version_id       | integer                     | NOT NULL
#  pacticipant_id   | integer                     | NOT NULL
#  environment_id   | integer                     | NOT NULL
#  created_at       | timestamp without time zone | NOT NULL
#  updated_at       | timestamp without time zone | NOT NULL
#  undeployed_at    | timestamp without time zone |
#  target           | text                        |
#  target_for_index | text                        | NOT NULL DEFAULT ''::text
# Indexes:
#  deployed_versions_pkey       | PRIMARY KEY btree (id)
#  deployed_versions_uuid_index | UNIQUE btree (uuid)
# Foreign key constraints:
#  deployed_versions_environment_id_fkey | (environment_id) REFERENCES environments(id)
#  deployed_versions_version_id_fkey     | (version_id) REFERENCES versions(id)
