require 'sqlite3'
require 'mysql2'
require 'yaml'

=begin

DB SCHEMA

 time_wanted DATETIME, reply_to_id TEXT, content TEXT, visibility TEXT, author TEXT, job_id TEXT

=end

# this extends the ResultSet class in SQLite3
#  to provide a count function
module SQLite3
  class ResultSet
    def count
      return self.columns.count
    end
  end
end

$db_data = {}

def remove_scheduled id
  DB_Client.query("DELETE FROM #{$db_data[:table]} WHERE reply_to_id = '#{id}'")
end


def cancel_scheduled id, author
  stmt = DB_Client.prepare("SELECT * FROM #{$db_data[:table]} WHERE author = ?")
  stmt.execute(author).each do |row|
    if row['reply_to_id'] == id.to_s
      remove_scheduled id
      $schedule_jobs[row['job_id']].unschedule
      $schedule_jobs[row['job_id']].kill
      return true
    end
  end
  return false
end
  

def db_from_file db = nil
  $db_data = YAML.load_file(db || 'db.yml')

  case $db_data[:type]
       
  when 'sqlite', nil
    SQLite3::Database.new($db_data[:database] + '.db')
    
  when 'mysql'
    Mysql2::Client.new(:host => $db_data[:host],
                       :username => $db_data[:user],
                       :password => $db_data[:pass],
                       :port => $db_data[:port],
                       :database => $db_data[:database],
                       :reconnect => true,
                       :database_timezone => :utc,
                       :application_timezone => :utc
                      )
  end
end

def load_from_db

  begin
    if DB_Client.is_a? SQLite3::Database and not DB_Client.results_as_hash
      DB_Client.results_as_hash = true
    end
    
    results = DB_Client.query("SELECT * from #{$db_data[:table]}")

    if results.count > 0
      results.each do |row|
        
        reschedule_toot(row['time_wanted'],
                        row['reply_to_id'],
                        row['content'],
                        row['visibility'])
        
      end
    end
  rescue Mysql2::Error
    DB_Client.query "CREATE TABLE #{$db_data[:table]} ( time_wanted DATETIME, reply_to_id TEXT, content TEXT, visibility TEXT, author TEXT, job_id TEXT )"

  rescue SQLite3::Exception
    DB_Client.query "CREATE TABLE #{$db_data[:table]} ( time_wanted TEXT, reply_to_id TEXT, content TEXT, visibility TEXT, author TEXT, job_id TEXT )"
  end
  
  
end

def write_db_data(time_wanted, reply_to, content, visibility, author, job_id)
  stmt = DB_Client.prepare "INSERT INTO #{$db_data[:table]} VALUES (?, ?, ?, ?, ?, ?)"

  begin
    stmt.execute(time_wanted, reply_to, content, visibility, author, job_id)

  rescue RuntimeError
    stmt.execute(time_wanted.to_s, reply_to, content, visibility, author, job_id)
  end
end
