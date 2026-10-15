extends RefCounted
## Base class for unit tests. Assertions record failures instead of aborting, so one run
## reports every broken expectation.

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func eq(actual, expected, message: String) -> void:
	if actual != expected:
		failures.append("%s: got %s, want %s" % [message, str(actual), str(expected)])


func near(actual: float, expected: float, epsilon: float, message: String) -> void:
	if absf(actual - expected) > epsilon:
		failures.append("%s: got %f, want %f (±%f)" % [message, actual, expected, epsilon])
