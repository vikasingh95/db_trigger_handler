module SQL
  def self.subscribe_channel(connection, channel)
    execute_query(connection, "LISTEN #{channel}")
  end

  private
  def execute_query(connection, query)
    connection.execute(query)
  end
end
