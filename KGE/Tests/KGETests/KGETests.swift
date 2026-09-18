import Testing

@Suite("KGE smoke tests")
struct KGETests {
    @Test("scaffold sanity check")
    func sanity() {
        #expect(1 + 1 == 2)
    }
}
