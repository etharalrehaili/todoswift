import Foundation

// ------------------- Model -------------------
struct Todo: Codable, CustomStringConvertible {
    var id: UUID // auto generated
    var title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }

    var description: String {
        let box = isCompleted ? "✅" : "❌"
        return "\(box) \(title)"
    }
}

// ------------------- Cache -------------------
protocol Cache {
    // persists the given todos
    func save(todos: [Todo]) -> Bool

    // retrieves and returns the saved todos, or nil if none exists
    func load() -> [Todo]?
}

// ------------------- File Manager Cache -------------------
final class JSONFileManagerCache: Cache {
    private let fileURL: URL

    // initialization
    init(fileName: String = "todos.json", directory: URL? = nil) {
        if let directory {
            self.fileURL = directory.appendingPathComponent(fileName)
        } else {
            let cwd = URL(
                fileURLWithPath: FileManager.default.currentDirectoryPath
            )
            self.fileURL = cwd.appendingPathComponent(fileName)
        }
    }

    func save(todos: [Todo]) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(todos)
            try data.write(to: fileURL, options: [.atomic])
            return true
        } catch {
            fputs("⚠️ Save error: \(error)\n", stderr)
            return false
        }
    }

    func load() -> [Todo]? {
        do {
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                return nil
            }
            let data = try Data(contentsOf: fileURL)
            if data.isEmpty { return nil }
            return try JSONDecoder().decode([Todo].self, from: data)
        } catch {
            fputs("⚠️ Load error: \(error)\n", stderr)
            return nil
        }
    }
}

// ------------------- In Memory Cache -------------------
final class InMemoryCache: Cache {
    private var storage: [Todo] = []

    func save(todos: [Todo]) -> Bool {
        storage = todos
        return true
    }

    func load() -> [Todo]? {
        storage.isEmpty ? nil : storage
    }
}

// ------------------- Todos Manager -------------------
final class TodosManager {
    private var todos: [Todo]
    private let cache: Cache

    // quick check for UI flow
    var hasTodos: Bool { !todos.isEmpty }

    // initialization
    init(cache: Cache) {
        self.cache = cache
        self.todos = cache.load() ?? []
    }

    // insert a new todo
    func addTodo(_ title: String) -> Todo {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let todo = Todo(title: trimmed)
        todos.append(todo)
        _ = cache.save(todos: todos)
        return todo
    }

    // display all todos
    func listTodos() {
        if todos.isEmpty {
            print("📝 No todos yet. Use 'add' to create one.")
            return
        }
        print("📝 Your todos:")
        for (i, todo) in todos.enumerated() {
            let box = todo.isCompleted ? "✅" : "❌"
            print("\(i + 1). \(box) \(todo.title)")
        }
    }

    // alter the completion status of a specific todo using its index
    func toggleCompletion(at index: Int) {
        guard todos.indices.contains(index) else {
            print("⚠️ Invalid index.")
            return
        }
        todos[index].isCompleted.toggle()
        _ = cache.save(todos: todos)
    }

    // remove a todo using its index
    func deleteTodo(at index: Int) {
        guard todos.indices.contains(index) else {
            print("⚠️ Invalid index.")
            return
        }
        todos.remove(at: index)
        _ = cache.save(todos: todos)
    }
}

// ------------------- App -------------------
final class App {
    private let manager: TodosManager

    init(manager: TodosManager) {
        self.manager = manager
    }

    // command enum helps interpret and execute user-entered commands
    enum Command: String {
        case add, list, toggle, delete, exit, help
    }

    private func prompt(_ text: String) -> String? {
        print(text, terminator: "")
        return readLine()
    }

    private func parseCommand(_ input: String) -> Command? {
        switch input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "add", "a": return .add
            case "list", "l": return .list
            case "toggle", "t": return .toggle
            case "delete", "del", "d", "rm": return .delete
            case "exit", "quit", "q": return .exit
            case "help", "h", "?": return .help
            default: return nil
        }
    }

    private func printMenu() {
        print(
            """
            ❓ Available commands:
            - add       ➕ Add a new todo
            - list      📋 List all todos
            - toggle    🔁 Toggle completion for an item
            - delete    🗑️ Delete an item
            - exit      ❌ Quit
            """
        )
    }

    // for keeping the application running and listening to user commands
    // await user input and execute commands
    func run() {
        print("🗒️ Simple Todos")
        printMenu()
        while true {
            guard let cmdLine = prompt("> Enter command (add, list, toggle, delete, exit): ") else {
                print("\n👋 Exiting.")
                break
            }
            guard let command = parseCommand(cmdLine) else {
                print("⚠️ Unknown command. Type one of: add, list, toggle, delete, exit")
                continue
            }
            switch command {
                case .add:
                    guard let title = prompt("Enter title: "),
                          !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        print("⚠️ Title cannot be empty.")
                        continue
                    }
                    let todo = manager.addTodo(title)
                    print("🎉 Added: \(todo.title)")
                case .list:
                    manager.listTodos()
                case .toggle:
                    guard let input = prompt("Enter item number to toggle: "),
                          let n = Int(input.trimmingCharacters(in: .whitespaces)), n > 0 else {
                        print("⚠️ Please enter a valid number greater than 0.")
                        continue
                    }
                    manager.toggleCompletion(at: n - 1)
                    print("🔁 Toggled item #\(n)")
                case .delete:
                    // List todos first, then ask for number
                    manager.listTodos()
                    if !manager.hasTodos {
                        continue
                    }
                    guard let input = prompt("Enter item number to delete: "),
                          let n = Int(input.trimmingCharacters(in: .whitespaces)), n > 0 else {
                        print("⚠️ Please enter a valid number greater than 0.")
                        continue
                    }
                    manager.deleteTodo(at: n - 1)
                    print("🗑️ Deleted item #\(n)")
                case .exit:
                    print("👋 Goodbye!")
                    return
                case .help:
                    printMenu()
            }
        }
    }
}

// Set up and run the app.
let cache: Cache = JSONFileManagerCache()
let manager = TodosManager(cache: cache)
let app = App(manager: manager)
app.run()
