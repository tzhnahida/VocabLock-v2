import { useState } from 'react'
import { dyn, type Lang } from '../i18n'
import { createWord, deleteWord, updateWord, type Word, type WordInput } from '../api'

type Props = {
  lang: Lang
  language: string
  word?: Word
  onClose: () => void
  onSaved: () => void
}

/** Add/edit form. Kept deliberately small: the four columns the table shows. */
export default function WordDialog({ lang, language, word, onClose, onSaved }: Props) {
  const editing = Boolean(word)
  const [input, setInput] = useState<WordInput>({
    word: word?.word ?? '',
    reading: word?.reading ?? '',
    meaning: word?.meaning ?? '',
    pos: word?.pos ?? ''
  })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const copy = dyn[lang]

  async function save(): Promise<void> {
    if (busy) return
    if (input.word.trim() === '') {
      setError(copy.wordLabel)
      return
    }
    setBusy(true)
    setError('')
    try {
      if (editing && word) await updateWord(word.id, input)
      else await createWord(input, language)
      onSaved()
      onClose()
    } catch (e) {
      setError(copy.saveFailed(e instanceof Error ? e.message : String(e)))
    } finally {
      setBusy(false)
    }
  }

  async function remove(): Promise<void> {
    if (!word || busy) return
    setBusy(true)
    try {
      await deleteWord(word.id)
      onSaved()
      onClose()
    } catch (e) {
      setError(copy.saveFailed(e instanceof Error ? e.message : String(e)))
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="backdrop" onClick={onClose}>
      <div className="dialog" onClick={(e) => e.stopPropagation()}>
        <h3>{editing ? copy.editTitle : copy.addTitle}</h3>

        <div className="field">
          <label>{copy.wordLabel}</label>
          <input value={input.word} onChange={(e) => setInput({ ...input, word: e.target.value })} autoFocus />
        </div>
        <div className="field">
          <label>{copy.readingLabel}</label>
          <input value={input.reading} onChange={(e) => setInput({ ...input, reading: e.target.value })} />
        </div>
        <div className="field">
          <label>{copy.meaningLabel}</label>
          <input value={input.meaning} onChange={(e) => setInput({ ...input, meaning: e.target.value })} />
        </div>
        <div className="field">
          <label>{copy.posLabel}</label>
          <input value={input.pos} onChange={(e) => setInput({ ...input, pos: e.target.value })} />
        </div>

        {error ? <div className="err">{error}</div> : null}

        <div className="row">
          <button className="btn ghost" onClick={onClose} disabled={busy}>
            {copy.cancel}
          </button>
          {editing ? (
            <button className="btn danger" onClick={() => void remove()} disabled={busy}>
              {copy.remove}
            </button>
          ) : null}
          <button className="btn" onClick={() => void save()} disabled={busy}>
            {copy.save}
          </button>
        </div>
      </div>
    </div>
  )
}
