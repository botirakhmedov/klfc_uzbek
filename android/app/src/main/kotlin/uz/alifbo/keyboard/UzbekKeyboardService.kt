package uz.alifbo.keyboard

import android.inputmethodservice.InputMethodService
import android.text.InputType
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo

/** The input method itself: it owns the view and writes into whatever field has focus. */
class UzbekKeyboardService : InputMethodService(), KeyboardListener {

    private lateinit var keyboard: KeyboardView

    override fun onCreateInputView(): View {
        keyboard = KeyboardView(this).also { it.listener = this }
        return keyboard
    }

    override fun onStartInputView(info: EditorInfo, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        keyboard.reset()
        keyboard.setAutoShift(shouldCapitalise(info))
    }

    private fun shouldCapitalise(info: EditorInfo): Boolean {
        val variation = info.inputType and InputType.TYPE_MASK_CLASS
        if (variation != InputType.TYPE_CLASS_TEXT) return false
        if (info.inputType and InputType.TYPE_TEXT_FLAG_CAP_SENTENCES == 0) return false
        val before = currentInputConnection?.getTextBeforeCursor(2, 0) ?: return true
        return before.isEmpty() || before.trimEnd().let { it.isEmpty() || it.endsWith(".") }
    }

    override fun onText(text: String) {
        currentInputConnection?.commitText(text, 1)
        refreshAutoShift()
    }

    override fun onDelete() {
        val ic = currentInputConnection ?: return
        val selected = ic.getSelectedText(0)
        if (selected.isNullOrEmpty()) {
            // deleteSurroundingTextInCodePoints keeps ʼ and any future multi-unit
            // characters from being cut in half.
            ic.deleteSurroundingTextInCodePoints(1, 0)
        } else {
            ic.commitText("", 1)
        }
        refreshAutoShift()
    }

    override fun onEnter() {
        val info = currentInputEditorInfo
        val action = info.imeOptions and EditorInfo.IME_MASK_ACTION
        val hasAction = action != EditorInfo.IME_ACTION_NONE &&
            info.imeOptions and EditorInfo.IME_FLAG_NO_ENTER_ACTION == 0
        if (hasAction) {
            currentInputConnection?.performEditorAction(action)
        } else {
            sendKeyEvent(KeyEvent.KEYCODE_ENTER)
        }
    }

    override fun onSwitchIme() {
        switchToNextInputMethod(false)
    }

    private fun refreshAutoShift() {
        keyboard.setAutoShift(shouldCapitalise(currentInputEditorInfo))
    }

    private fun sendKeyEvent(code: Int) {
        val ic = currentInputConnection ?: return
        ic.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
        ic.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
    }
}
