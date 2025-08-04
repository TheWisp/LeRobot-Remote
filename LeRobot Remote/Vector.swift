import Foundation

struct vector {
    var x: Double
    var y: Double
    var z: Double
    // Implement common operators
    static func * (lhs: vector, rhs: Double) -> vector {
        return .init(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }
    static func * (lhs: Double, rhs: vector) -> vector {
        return .init(x: lhs * rhs.x, y: lhs * rhs.y, z: lhs * rhs.z)
    }
    static func += (lhs: inout vector, rhs: vector) {
        lhs.x += rhs.x
        lhs.y += rhs.y
        lhs.z += rhs.z
    }
    static func -= (lhs: inout vector, rhs: vector) {
        lhs.x -= rhs.x
        lhs.y -= rhs.y
        lhs.z -= rhs.z
    }
    static func + (lhs: vector, rhs: vector) -> vector {
        return .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
    static func - (lhs: vector, rhs: vector) -> vector {
        return .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }
    //impl lengthSquared
    func lengthSquared() -> Double {
        return x * x + y * y + z * z
    }
    func distance(to other: vector) -> Double {
        let dx = self.x - other.x
        let dy = self.y - other.y
        let dz = self.z - other.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
}
