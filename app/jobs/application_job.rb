class ApplicationJob < ActiveJob::Base
  # Transient infrastructure hiccups - a lock timeout under concurrent
  # webhook delivery, a dropped DB connection - shouldn't permanently strand
  # a payment mid-update; without this, Solid Queue moves a job straight to
  # failed_executions on the first error and never looks at it again.
  # Business-logic failures (e.g. Payment::InvalidTransition) are caught and
  # recorded inside the jobs themselves rather than raised, so they never
  # reach this and are correctly never retried.
  retry_on ActiveRecord::Deadlocked, ActiveRecord::ConnectionNotEstablished, PG::ConnectionBad,
           wait: :polynomially_longer, attempts: 5

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError
end
