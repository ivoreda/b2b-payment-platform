class ApplicationJob < ActiveJob::Base
  # Retries transient infra errors; business-logic failures are caught inside the jobs themselves and never reach here.
  retry_on ActiveRecord::Deadlocked, ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad,
           wait: :polynomially_longer, attempts: 5

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError
end
