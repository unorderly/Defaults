/**
Stores a macro-generated Defaults observation task with its owning model.

The task is cancelled when that owner deinitializes.
*/
public final class ObservableDefaultTaskStorage: @unchecked Sendable {
	// The association only uses Objective-C associated-object operations, which are thread-safe.
	// Its values only retain a Task, whose cancellation is thread-safe.
	private let taskLifetimes = ObjectAssociation<TaskLifetime>()

	public init() {}

	public func containsTask(for owner: AnyObject) -> Bool {
		taskLifetimes[owner] != nil
	}

	public func store(_ task: Task<Void, Never>, for owner: AnyObject) {
		taskLifetimes[owner] = TaskLifetime(task)
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
