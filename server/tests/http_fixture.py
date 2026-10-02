import os
from app import Application, Store

def create_app():
    store = Store(os.environ["COWRITTEN_DATABASE"])
    def upstream(text, _key, _model):
        return {"summary": "A fixture result.", "voice": "First person.", "formality": "Neutral.",
                "strengths": ["Clear subject."], "suggestions": [], "caveat": "Fixture only.", "aiWriting": {"summary": "No supported cues.", "signals": [], "limitations": "Style cannot establish authorship."}}
    return Application(store, "mock-provider-key", "mock-model", upstream=upstream)
