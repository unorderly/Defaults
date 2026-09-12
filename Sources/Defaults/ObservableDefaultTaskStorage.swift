/**
Stores a macro-generated Defaults observation task with its owning model.

The task is cancelled when that owner deinitializes.
*/
extension Defaults {
	@_documentation(visibility: private)
	public final class ObservableDefaultTaskStorage: @unchecked Sendable {
		// This lock makes lookup, stream registration, task construction, and association one operation.
		// The associated-object calls are non-atomic, so they are never used outside this critical section.
		// The `@unchecked Sendable` invariant is that the lock guards all storage access and retained Tasks
		// are only cancelled, which is thread-safe.
		private let lock: Lock = .make()
		private let taskLifetimes = ObjectAssociation<TaskLifetime>()

		public init() {}

		public func installIfNeeded<Start>(
			for owner: AnyObject,
			create: () -> (task: Task<Void, Never>, start: Start),
			start: (Start) -> Void
		) {
			lock.lock()
			guard taskLifetimes[owner] == nil else {
				lock.unlock()
				return
			}

			let installation = create()
			taskLifetimes[owner] = TaskLifetime(installation.task)
			lock.unlock()

			start(installation.start)
		}

		private final class TaskLifetime {
			private let task: Task<Void, Never>

			init(_ task: Task<Void, Never>) {
				self.task = task
			}

			deinit {
				task.cancel()
			}
		}
	}
}
