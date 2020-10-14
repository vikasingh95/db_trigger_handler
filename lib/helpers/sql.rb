module SQL
  class << self
    def subscribe_channel(connection, channel)
      execute_query(connection, "LISTEN #{channel}")
    end

    def unsubscribe_channel(connection, channel)
      execute_query(connection, "UNLISTEN #{channel}")
    end

    private
    def execute_query(connection, query)
      connection.execute(query)
    end
  end
end
