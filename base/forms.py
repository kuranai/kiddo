from django import forms

from .models import Todo


class TodoForm(forms.ModelForm):
    due_time = forms.TimeField(
        required=False,
        widget=forms.TimeInput(attrs={"type": "time"}),
        help_text="Set a time for this task (optional)",
    )

    class Meta:
        model = Todo
        fields = ["title", "description", "completed", "recurrence", "due_time"]
