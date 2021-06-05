import JavaScriptKit

class Benchmark {
    init(_ title: String) {
        self.title = title
    }

    let title: String
    let runner = JSObject.global.benchmarkRunner.function!

    func testSuite(_ name: String, _ body: @escaping () -> Void) {
        let jsBody = JSClosure { arguments -> JSValue in
            let iteration = Int(arguments[0].number!)
            for _ in 0 ..< iteration { body() }
            return .undefined
        }
        runner("\(title)/\(name)", jsBody)
    }
}
