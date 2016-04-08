module JobNotifier
  module Notifier
    extend ActiveSupport::Concern

    included do
      attr_accessor :job_identifier

      def perform(*args)
        self.job_identifier = args.shift
        result = perform_with_feedback(*args)
        save_success_feedback(result)
      rescue JobNotifier::Error::Validation => ex
        save_error_feedback(ex.error)
      rescue StandardError => ex
        save_error_feedback("unknown")
        raise ex
      end

      def save_error_feedback(error)
        on_job_ctx do |job|
          job.update_column(:result, error.to_s)
        end
      end

      def save_success_feedback(data)
        on_job_ctx do |job|
          job.update_column(:result, data.to_s)
        end
      end

      def on_job_ctx(&block)
        job = JobNotifier::Job.job_by_identifier(job_identifier)
        return unless job
        block.call(job)
      end

      before_enqueue do |job|
        identifier = job.arguments.first
        raise JobNotifier::Error::InvalidIdentifier if identifier.blank?
        JobNotifier::Job.create!(decoded_identifier: identifier)
      end
    end
  end
end

ActiveJob::Base.include(JobNotifier::Notifier)
