class ExportData
  include SuckerPunch::Job

  def perform(token, week)
    p "starting to export"
    ActiveRecord::Base.connection_pool.with_connection do
      begin
        OutputWeek.write(token, week)
      rescue => error
        p "ERROR"
        p error.message
      end
    end
    p "finished exporting"
  end
end