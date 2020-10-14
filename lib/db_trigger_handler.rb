require "db_trigger_handler/version"
require "helpers/sql"

module DbTriggerHandler
  include SQL

  class << self
    def init(active_record_base)
      return if active_record_base.blank?
      @active_record_base = active_record_base
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
          @active_record_base..clear_active_connections!
        end
      end
    end

    def subscribe
      notification_channels.each do |channel|
        SQL.subscribe_channel(@connection, channel)
      end
    end

    def listen
      begin
        loop do
          @connection.raw_connection.wait_for_notify do |event, id, data|
            pp "MessageReceived :- #{event}, #{id}, #{data}"
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
      %w[SHIPMENT_CREATED SHIPMENT_CHANGED DPIR_CHANGED TRIGGER_FAILED]
    end
  end
end
