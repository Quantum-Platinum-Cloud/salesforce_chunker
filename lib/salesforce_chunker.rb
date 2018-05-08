require "salesforce_chunker/connection.rb"
require "salesforce_chunker/job.rb"

module SalesforceChunker
  class Client

    def initialize(username, password, security_token, domain="test", sf_version="42.0", retry_seconds=10)
      @connection = SalesforceChunker::Connection.new(username, password, security_token, domain, sf_version)
      @retry_seconds = retry_seconds
    end

    def query(soql="SELECT Name FROM Account", batch_size=10000)

      raise StandardError.new("no block given") unless block_given?

      job = SalesforceChunker::Job.new(@connection, soql, batch_size)
      retrieved_batch_ids = []

      # timeout after some period?
      while true
        job.get_batch_statuses.each do |status|
          batch_id = status["id"]

          next if retrieved_batch_ids.include?(batch_id)

          # need to handle failed states
          if status["state"] == "Completed"
            if status["numberRecordsProcessed"] > 0
              job.retrieve_batch_results(batch_id).each do |result_id|
                job.retrieve_results(batch_id, result_id).each do |result|

                  # only works for Name
                  name = result["Name"]
                  yield(name)
                end
              end
            end

            retrieved_batch_ids.append(batch_id)
          end
        end

        break if job.batches_count && retrieved_batch_ids.length == job.batches_count
        sleep(@retry_seconds)
      end
    end
  end
end
