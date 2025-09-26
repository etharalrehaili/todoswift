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
        let box = isCompleted ? "[x]" : "[ ]"
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
            fputs("Save error: \(error)\n", stderr)
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
            fputs("Load error: \(error)\n", stderr)
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
            print("No todos yet. Use 'add <title>' to create one.")
            return
        }
        for (i, todo) in todos.enumerated() {
            let box = todo.isCompleted ? "[x]" : "[ ]"
            print("\(i + 1). \(box) \(todo.title)")
        }
    }

    // alter the completion status of a specific todo using its index
    func toggleCompletion(at index: Int) {
        guard todos.indices.contains(index) else {
            print("Invalid index.")
            return
        }
        todos[index].isCompleted.toggle()
        _ = cache.save(todos: todos)
    }

    // remove a todo using its index
    func deleteTodo(at index: Int) {
        guard todos.indices.contains(index) else {
            print("Invalid index.")
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
    enum Command {
        case add(String)
        case list
        case toggle(Int)
        case delete(Int)
        case help
        case exit
    }

    private func parse(_ line: String) -> Command {
        let parts = line.split(
            separator: " ",
            maxSplits: 1,
            omittingEmptySubsequences: true
        )
        guard let first = parts.first?.lowercased() else { return .help }
        switch first {
        case "add":
            let title = parts.count > 1 ? String(parts[1]) : ""
            return .add(title)
        case "list":
            return .list
        case "toggle":
            if parts.count > 1, let n = Int(parts[1].trimmingCharacters(in: .whitespaces)), n > 0 {
                return .toggle(n - 1)
            }
            return .help
        case "delete", "del", "rm":
            if parts.count > 1, let n = Int(parts[1].trimmingCharacters(in: .whitespaces)), n > 0 {
                return .delete(n - 1)
            }
            return .help
        case "help", "?":
            return .help
        case "exit", "quit", "q":
            return .exit
        default:
            return .help
        }
    }

    private func printHelp() {
        print(
            """
            Available commands:
            - add <title>    Add a new todo
            - list            List all todos
            - toggle <n>     Toggle completion for item n
            - delete <n>     Delete item n
            - help            Show this help
            - exit            Quit
            """
        )
    }

    // for keeping the application running and listening to user commands
    // await user input and execute commands
    func run() {
        print("Simple Todos — type 'help' for commands.")
        manager.listTodos()
        while true {
            print("> ", terminator: "")
            guard let line = readLine() else {
                print("\nExiting.")
                break
            }
            let command = parse(line)
            switch command {
            case .add(let title):
                if title
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("Please provide a title: add <title>")
                } else {
                    let todo = manager.addTodo(title)
                    print("Added: \(todo.title)")
                }
            case .list:
                manager.listTodos()
            case .toggle(let idx):
                manager.toggleCompletion(at: idx)
            case .delete(let idx):
                manager.deleteTodo(at: idx)
            case .help:
                printHelp()
            case .exit:
                print("Goodbye!")
                return
            }
        }
    }
}

// Set up and run the app.
let cache: Cache = JSONFileManagerCache()
let manager = TodosManager(cache: cache)
let app = App(manager: manager)
app.run()
