require 'sequel'
require 'pact_broker/domain/version'
require 'pact_broker/tags/repository'

module PactBroker
  module Versions
    class Repository

      include PactBroker::Repositories::Helpers

      def find_by_pacticipant_id_and_number pacticipant_id, number
        PactBroker::Domain::Version.where(number: number, pacticipant_id: pacticipant_id).single_record
      end

      def find_by_pacticipant_name_and_latest_tag pacticipant_name, tag
        PactBroker::Domain::Version
          .select_all_qualified
          .join(:pacticipants, {id: :pacticipant_id}, {implicit_qualifier: :versions})
          .join(:tags, {version_id: :id}, {implicit_qualifier: :versions})
          .where(name_like(Sequel[:tags][:name], tag))
          .where(name_like(Sequel[:pacticipants][:name], pacticipant_name))
          .reverse_order(:order)
          .first
      end

      def find_by_pacticipant_name_and_tag pacticipant_name, tag
        PactBroker::Domain::Version
          .select_all_qualified
          .join(:pacticipants, {id: :pacticipant_id}, {implicit_qualifier: :versions})
          .join(:tags, {version_id: :id}, {implicit_qualifier: :versions})
          .where(name_like(Sequel[:tags][:name], tag))
          .where(name_like(Sequel[:pacticipants][:name], pacticipant_name))
          .all
      end

      def find_latest_by_pacticpant_name pacticipant_name
        PactBroker::Domain::Version
          .select_all_qualified
          .join(:pacticipants, {id: :pacticipant_id}, {implicit_qualifier: :versions})
          .where(name_like(Sequel[:pacticipants][:name], pacticipant_name))
          .reverse_order(:order)
          .first
      end

      def find_by_pacticipant_name_and_number pacticipant_name, number
        PactBroker::Domain::Version
          .select(Sequel[:versions][:id], Sequel[:versions][:number], Sequel[:versions][:pacticipant_id], Sequel[:versions][:order], Sequel[:versions][:created_at], Sequel[:versions][:updated_at])
          .join(:pacticipants, {id: :pacticipant_id})
          .where(name_like(:number, number))
          .where(name_like(:name, pacticipant_name))
          .single_record
      end

      # There may be a race condition if two simultaneous requests come in to create the same version
      def create args
        PactBroker.logger.info "Upserting version #{args[:number]} for pacticipant_id=#{args[:pacticipant_id]}"
        version_params = {
          number: args[:number],
          pacticipant_id: args[:pacticipant_id],
          created_at: Sequel.datetime_class.now,
          updated_at: Sequel.datetime_class.now
        }
        id = PactBroker::Domain::Version.dataset.insert_ignore.insert(version_params)
        version = PactBroker::Domain::Version.find(number: args[:number], pacticipant_id: args[:pacticipant_id])
        PactBroker::Domain::OrderVersions.(version)
        version.refresh # reload with the populated order
      end

      def find_by_pacticipant_id_and_number_or_create pacticipant_id, number
        if version = find_by_pacticipant_id_and_number(pacticipant_id, number)
          version
        else
          create(pacticipant_id: pacticipant_id, number: number)
        end
      end

      def delete_by_id version_ids
        Domain::Version.where(id: version_ids).delete
      end
    end
  end
end
