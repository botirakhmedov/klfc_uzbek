package uz.alifbo.keyboard

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LayoutsTest {

    private fun reachable(page: Page): Set<String> =
        Layouts.rows(page).flatten().flatMap { listOf(it.output) + it.alternates }.toSet()

    @Test
    fun `every letter of the 2026 alphabet is on the letter page`() {
        val keys = reachable(Page.LETTERS)
        val missing = Layouts.alphabet.filterNot { keys.contains(it.toString()) }
        assertEquals("letters missing from the board: $missing", "", missing)
    }

    @Test
    fun `the tutuq belgisi is U+02BC and has its own key`() {
        assertEquals("ʼ", TUTUQ)
        val ownKeys = Layouts.rows(Page.LETTERS).flatten().filter { it.output == TUTUQ }
        assertEquals(1, ownKeys.size)
    }

    @Test
    fun `w and c are reachable even though they left the alphabet`() {
        val keys = reachable(Page.LETTERS)
        assertTrue("w is unreachable", keys.contains("w"))
        assertTrue("c is unreachable", keys.contains("c"))
    }

    @Test
    fun `every letter row spans the same width`() {
        val rows = Layouts.rows(Page.LETTERS)
        val widths = rows.map { row -> row.sumOf { it.weight.toDouble() } }
        assertTrue("rows have different widths: $widths", widths.distinct().size == 1)
    }

    @Test
    fun `every page can be left again`() {
        Page.entries.forEach { page ->
            val targets = Layouts.rows(page).flatten().mapNotNull { it.pageTarget }
            if (page != Page.LETTERS) {
                assertTrue("$page has no way back to letters", targets.contains(Page.LETTERS))
            }
        }
    }

    @Test
    fun `delete and enter exist on every page`() {
        Page.entries.forEach { page ->
            val actions = Layouts.rows(page).flatten().map { it.action }.toSet()
            assertTrue("$page has no delete", actions.contains(KeyAction.DELETE))
            assertTrue("$page has no enter", actions.contains(KeyAction.ENTER))
        }
    }
}
