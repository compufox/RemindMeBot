require 'mysql2'
require 'yaml'

=begin

DB SCHEMA

 time_wanted DATETIME, reply_to_id NUMERIC, content TEXT, visibility TEXT

=end

$db_data = {}

def remove_scheduled id
  DB_Client.query("DELETE FROM #{$db_data[:table]} WHERE reply_to_id = '#{id}'")
end


def cancel_scheduled id, author
  DB_Client.query("SELECT * FROM #{$db_data[:table]} WHERE author = '#{author}'").each do |row|
    if row['reply_to_id'] == id
      remove_scheduled id
      return true
    end
  end
  return false
end
  

def db_from_file db = nil
  $db_data = YAML.load_file(db || 'db.yml')

  Mysql2::Client.new( :host => $db_data[:host],
                     :username => $db_data[:user],
                     :password => $db_data[:pass],
                     :port => $db_data[:port],
                     :database => $db_data[:database],
                     :reconnect => true,
                     :database_timezone => :utc,
                     :application_timezone => :utc
                   )
end

def load_from_db

  begin
    results = DB_Client.query("SELECT * from #{$db_data[:table]}")
    
    if results.count > 0
      results.each do |row|
        
        reschedule_toot(row['time_wanted'],
                        row['reply_to_id'],
                        row['content'],
                        row['visibility'])
        
      end
    end
  rescue Mysql2::Error => mye
    DB_Client.query "CREATE TABLE #{$db_data[:table]} ( time_wanted DATETIME, reply_to_id TEXT, content TEXT, visibility TEXT, author TEXT )"
  end
  
end

def write_db_data(time_wanted, reply_to, content, visibility, author)
  DB_Client.query "INSERT INTO #{$db_data[:table]} VALUES ( '#{time_wanted}', '#{reply_to}', '#{content}', '#{visibility}', '#{author}' )"
end
