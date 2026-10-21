package uz.alifbo.keyboard

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import androidx.core.content.ContextCompat
import kotlin.math.max

/** Where the shift key currently stands. */
enum class ShiftState { OFF, ON, LOCKED }

interface KeyboardListener {
    fun onText(text: String)
    fun onDelete()
    fun onEnter()
    fun onSwitchIme()
}

/**
 * Draws the board and turns touches into key presses.
 *
 * Everything is drawn onto one canvas rather than built from child views: a keyboard is
 * redrawn on every shift change and every page switch, and a flat canvas keeps that cheap
 * and keeps key geometry in one place.
 */
class KeyboardView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    var listener: KeyboardListener? = null

    var page: Page = Page.LETTERS
        private set

    var shift: ShiftState = ShiftState.OFF
        private set

    private val mainHandler = Handler(Looper.getMainLooper())

    /** A key with the screen rectangle it was laid out into. */
    private class Placed(val key: Key, val rect: RectF)

    private var placed: List<Placed> = emptyList()
    private var pressed: Placed? = null
    private var lastShiftTap = 0L

    private val keyPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
    }
    private val hintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
    }

    // Narrow horizontal gaps are what make a board feel wide: the stock keyboards leave
    // about 4dp between neighbouring keys, not the 6dp a symmetric 3dp gap would give.
    private val gapX = dp(2f)
    private val gapY = dp(4f)
    private val radius = dp(9f)
    private val rowHeight = dp(52f)
    private val paddingTop = dp(4f)
    private val paddingBottom = dp(8f)

    private val colBackground = ContextCompat.getColor(context, R.color.keyboard_background)
    private val colKey = ContextCompat.getColor(context, R.color.key_background)
    private val colKeySpecial = ContextCompat.getColor(context, R.color.key_background_special)
    private val colKeyPressed = ContextCompat.getColor(context, R.color.key_background_pressed)
    private val colKeyAccent = ContextCompat.getColor(context, R.color.key_background_accent)
    private val colText = ContextCompat.getColor(context, R.color.key_text)
    private val colHint = ContextCompat.getColor(context, R.color.key_hint)

    private var alternates: AlternatesPopup? = null

    private val longPress = Runnable {
        val target = pressed ?: return@Runnable
        if (target.key.alternates.isEmpty()) return@Runnable
        alternates = AlternatesPopup(this, target.rect, options(target.key)).also { it.show() }
    }

    private val deleteRepeat = object : Runnable {
        override fun run() {
            listener?.onDelete()
            mainHandler.postDelayed(this, 45L)
        }
    }

    private fun dp(value: Float) = value * resources.displayMetrics.density

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val rows = Layouts.rows(page).size
        val height = (rowHeight * rows + paddingTop + paddingBottom).toInt()
        setMeasuredDimension(width, height)
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        layoutKeys(w, h)
    }

    private fun layoutKeys(width: Int, height: Int) {
        val rows = Layouts.rows(page)
        if (rows.isEmpty() || width == 0) return
        val usableHeight = height - paddingTop - paddingBottom
        val rowH = usableHeight / rows.size
        val out = mutableListOf<Placed>()
        rows.forEachIndexed { rowIndex, row ->
            val totalWeight = row.sumOf { it.weight.toDouble() }.toFloat()
            val unit = width / totalWeight
            var x = 0f
            val y = paddingTop + rowIndex * rowH
            row.forEach { key ->
                val w = unit * key.weight
                out += Placed(key, RectF(x + gapX, y + gapY, x + w - gapX, y + rowH - gapY))
                x += w
            }
        }
        placed = out
    }

    fun setPage(next: Page) {
        page = next
        if (next != Page.LETTERS) shift = ShiftState.OFF
        requestLayout()
        layoutKeys(width, height)
        invalidate()
    }

    /** Reset to a lower-case letter board; called when a new text field is opened. */
    fun reset() {
        page = Page.LETTERS
        shift = ShiftState.OFF
        requestLayout()
        layoutKeys(width, height)
        invalidate()
    }

    fun setAutoShift(on: Boolean) {
        if (shift == ShiftState.LOCKED) return
        val next = if (on) ShiftState.ON else ShiftState.OFF
        if (next != shift) {
            shift = next
            invalidate()
        }
    }

    private fun shifted(key: Key): String =
        if (key.isLetter && shift != ShiftState.OFF) key.output.uppercase() else key.output

    private fun label(key: Key): String = when {
        key.action == KeyAction.SPACE -> context.getString(R.string.space_label)
        key.action == KeyAction.SHIFT -> if (shift == ShiftState.LOCKED) "⇪" else "⇧"
        key.isLetter && shift != ShiftState.OFF -> key.label.uppercase()
        else -> key.label
    }

    private fun options(key: Key): List<String> =
        (listOf(shifted(key)) + key.alternates).map {
            if (key.isLetter && shift != ShiftState.OFF) it.uppercase() else it
        }

    override fun onDraw(canvas: Canvas) {
        canvas.drawColor(colBackground)
        val letterSize = rowHeight * 0.44f
        val labelSize = rowHeight * 0.28f
        placed.forEach { p ->
            keyPaint.color = when {
                p === pressed -> colKeyPressed
                p.key.action == KeyAction.ENTER -> colKeyAccent
                p.key.action == KeyAction.SHIFT && shift != ShiftState.OFF -> colKeyAccent
                p.key.action == KeyAction.OUTPUT -> colKey
                else -> colKeySpecial
            }
            canvas.drawRoundRect(p.rect, radius, radius, keyPaint)

            val text = label(p.key)
            if (text.isNotEmpty()) {
                val isWord = text.length > 1 && p.key.action != KeyAction.OUTPUT
                textPaint.color = colText
                textPaint.textSize = if (isWord) labelSize else letterSize
                textPaint.typeface = if (p.key.isLetter) Typeface.DEFAULT else Typeface.DEFAULT_BOLD
                val baseline = p.rect.centerY() - (textPaint.descent() + textPaint.ascent()) / 2
                canvas.drawText(text, p.rect.centerX(), baseline, textPaint)
            }

            // the first alternate, printed small in the corner, the way number hints are shown
            val hint = p.key.hint ?: p.key.alternates.firstOrNull()
            if (hint != null && p.key.isLetter) {
                hintPaint.color = colHint
                hintPaint.textSize = rowHeight * 0.20f
                canvas.drawText(hint, p.rect.right - dp(9f), p.rect.top + dp(13f), hintPaint)
            }
        }
    }

    private fun keyAt(x: Float, y: Float): Placed? =
        placed.firstOrNull { it.rect.contains(x, y) }
            ?: placed.minByOrNull { p ->
                val dx = max(0f, max(p.rect.left - x, x - p.rect.right))
                val dy = max(0f, max(p.rect.top - y, y - p.rect.bottom))
                dx * dx + dy * dy
            }?.takeIf { p ->
                y >= paddingTop && y <= height - paddingBottom &&
                    max(0f, max(p.rect.top - y, y - p.rect.bottom)) < gapY * 2
            }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                val hit = keyAt(event.x, event.y) ?: return true
                pressed = hit
                invalidate()
                performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                if (hit.key.action == KeyAction.DELETE) {
                    listener?.onDelete()
                    mainHandler.postDelayed(deleteRepeat, 350L)
                } else if (hit.key.alternates.isNotEmpty()) {
                    mainHandler.postDelayed(longPress, 320L)
                }
            }

            MotionEvent.ACTION_MOVE -> {
                val popup = alternates
                if (popup != null) {
                    popup.moveTo(event.rawX)
                } else {
                    val hit = keyAt(event.x, event.y)
                    if (hit !== pressed) {
                        cancelPending()
                        pressed = hit
                        invalidate()
                        if (hit != null && hit.key.alternates.isNotEmpty()) {
                            mainHandler.postDelayed(longPress, 320L)
                        }
                    }
                }
            }

            MotionEvent.ACTION_UP -> {
                val popup = alternates
                val target = pressed
                cancelPending()
                if (popup != null) {
                    popup.selected()?.let { emit(it) }
                    popup.dismiss()
                    alternates = null
                } else if (target != null) {
                    release(target.key)
                }
                pressed = null
                invalidate()
            }

            MotionEvent.ACTION_CANCEL -> {
                cancelPending()
                alternates?.dismiss()
                alternates = null
                pressed = null
                invalidate()
            }
        }
        return true
    }

    private fun cancelPending() {
        mainHandler.removeCallbacks(longPress)
        mainHandler.removeCallbacks(deleteRepeat)
    }

    private fun emit(text: String) {
        listener?.onText(text)
        if (shift == ShiftState.ON) {
            shift = ShiftState.OFF
            invalidate()
        }
    }

    private fun release(key: Key) {
        when (key.action) {
            KeyAction.OUTPUT -> emit(shifted(key))
            KeyAction.SPACE -> emit(" ")
            KeyAction.ENTER -> listener?.onEnter()
            KeyAction.DELETE -> Unit // already handled on ACTION_DOWN
            KeyAction.SWITCH_IME -> listener?.onSwitchIme()
            KeyAction.SETTINGS -> Unit
            KeyAction.SWITCH_PAGE -> key.pageTarget?.let { setPage(it) }
            KeyAction.SHIFT -> {
                val now = System.currentTimeMillis()
                shift = when {
                    now - lastShiftTap < 300L -> ShiftState.LOCKED
                    shift == ShiftState.OFF -> ShiftState.ON
                    else -> ShiftState.OFF
                }
                lastShiftTap = now
                invalidate()
            }
        }
    }

    override fun onDetachedFromWindow() {
        cancelPending()
        alternates?.dismiss()
        alternates = null
        super.onDetachedFromWindow()
    }
}
