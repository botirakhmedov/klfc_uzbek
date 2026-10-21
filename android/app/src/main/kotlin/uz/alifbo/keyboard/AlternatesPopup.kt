package uz.alifbo.keyboard

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.drawable.ColorDrawable
import android.view.View
import android.widget.PopupWindow
import androidx.core.content.ContextCompat

/**
 * The row of alternates shown while a key is held down. The finger stays on the screen,
 * slides sideways to pick one, and lifting commits it — so this is a plain view that
 * tracks an x coordinate, not something with its own touch handling.
 */
class AlternatesPopup(
    private val anchor: KeyboardView,
    private val keyRect: RectF,
    private val options: List<String>,
) {
    private val context = anchor.context
    private val density = context.resources.displayMetrics.density
    private val cellWidth = 44f * density
    private val cellHeight = 52f * density
    private val padding = 4f * density

    private var selectedIndex = 0

    private val content = object : View(context) {
        private val bg = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = ContextCompat.getColor(context, R.color.popup_background)
        }
        private val highlight = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = ContextCompat.getColor(context, R.color.key_background_accent)
        }
        private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = ContextCompat.getColor(context, R.color.key_text)
            textAlign = Paint.Align.CENTER
            textSize = 22f * density
        }

        override fun onDraw(canvas: Canvas) {
            val r = 8f * density
            canvas.drawRoundRect(
                RectF(0f, 0f, width.toFloat(), height.toFloat()), r, r, bg
            )
            options.forEachIndexed { i, option ->
                val left = padding + i * cellWidth
                if (i == selectedIndex) {
                    canvas.drawRoundRect(
                        RectF(left, padding, left + cellWidth, padding + cellHeight),
                        r, r, highlight
                    )
                }
                val cx = left + cellWidth / 2
                val baseline = padding + cellHeight / 2 - (text.descent() + text.ascent()) / 2
                canvas.drawText(option, cx, baseline, text)
            }
        }
    }

    private val window = PopupWindow(
        content,
        (options.size * cellWidth + padding * 2).toInt(),
        (cellHeight + padding * 2).toInt(),
        false,
    ).apply {
        setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        isClippingEnabled = false
        isTouchable = false
    }

    private var originX = 0f

    fun show() {
        val location = IntArray(2)
        anchor.getLocationInWindow(location)
        // Keep the strip on screen: shift it left when the key is near the right edge.
        val screenWidth = context.resources.displayMetrics.widthPixels
        val desired = keyRect.centerX() - cellWidth / 2 - padding
        val maxX = screenWidth - window.width.toFloat()
        originX = desired.coerceIn(0f, if (maxX > 0) maxX else 0f)
        val y = location[1] + keyRect.top - window.height
        window.showAtLocation(anchor, android.view.Gravity.NO_GRAVITY, originX.toInt(), y.toInt())
    }

    /** Called while the finger moves; [rawX] is a screen coordinate. */
    fun moveTo(rawX: Float) {
        val index = (((rawX - originX - padding) / cellWidth).toInt())
            .coerceIn(0, options.size - 1)
        if (index != selectedIndex) {
            selectedIndex = index
            content.invalidate()
        }
    }

    fun selected(): String? = options.getOrNull(selectedIndex)

    fun dismiss() = window.dismiss()
}
