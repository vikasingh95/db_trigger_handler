require "db_trigger_handler/version"
require "helpers/sql"
require 'handlers/shipment_handler'
require 'handlers/dpir_handler'
require 'handlers/dp_handler'
require 'logger'

module DbTriggerHandler
  include SQL
  include ShipmentHandler
  include DpirHandler
  include DpHandler

  class << self
    def init(active_record_base, active, kafka_broker)
      return if active_record_base.blank?
      @active_record_base = active_record_base
      @logger = Logger.new("log/db_trigger.log")
      @logger.info("Info :- #{active}")
      @logger.info("Kafka Broker :- #{kafka_broker}")
      return unless active
      @kafka_broker = kafka_broker
      execute
    end

    private
    def execute
      Thread.new do
        begin
          @active_record_base.connection_pool.with_connection do |connection|
            @connection = connection
            subscribe
            listen
          end
        ensure
          @logger.info "Closing"
          @active_record_base.clear_active_connections!
        end
      end
    end

    def subscribe
      notification_channels.each do |channel|
        @logger.info "Subscribed :- #{channel}"
        SQL.subscribe_channel(@connection, channel)
      end
    end

    def listen
      begin
        loop do
          @connection.raw_connection.wait_for_notify do |event, id, data|
            begin
              @logger.info "Listened :- #{event}, #{data}"
              case event
              when 'shipment_created'
                ShipmentHandler.shipment_create_handler(@connection, data, @logger, @kafka_broker)
              when 'shipment_updated'
                ShipmentHandler.shipment_updated(@connection, data, @logger, @kafka_broker)
              when 'shipment_delivered'
                ShipmentHandler.shipment_delivered(@connection, data, @logger, @kafka_broker)
              when 'shipment_dpir_changed'
                ShipmentHandler.shipment_dpir_transaction_handler(@connection, data, @logger, @kafka_broker)
              when 'dpir_updated'
                DpirHandler.handle_dpir_change(@connection, data, @logger, @kafka_broker)
              when 'dp_updated'
                DpHandler.handle_dp_updates(@connection, data, @logger, @kafka_broker)
              end
            rescue => e
              @logger.error(e)
            end
          end
        end
      ensure
        unsubscribe
      end
    end

    def unsubscribe
      notification_channels.each do |channel|
        SQL.unsubscribe_channel(@connection, channel)
      end
    end

    def notification_channels
      %w[shipment_created shipment_delivered shipment_dpir_changed shipment_updated dpir_updated dp_updated]
    end
  end
end
