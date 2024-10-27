from django.contrib.auth.models import User
from django.db import models
from django.utils import timezone


# Create your models here.
class Todo(models.Model):
    RECURRENCE_CHOICES = [
        ("none", "No Recurrence"),
        ("daily", "Daily"),
        ("weekly", "Weekly"),
        ("monthly", "Monthly"),
    ]

    title = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    completed = models.BooleanField(default=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # New fields for recurring tasks
    recurrence = models.CharField(
        max_length=10, choices=RECURRENCE_CHOICES, default="none"
    )
    due_time = models.TimeField(null=True, blank=True)
    parent_todo = models.ForeignKey(
        "self", null=True, blank=True, on_delete=models.SET_NULL
    )
    next_occurrence = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return self.title

    def create_next_occurrence(self):
        if self.recurrence == "none" or not self.due_time:
            return None

        # Get current time
        now = timezone.now()

        # Calculate the base date for next occurrence
        if self.next_occurrence:
            base_date = self.next_occurrence
        else:
            # If no next_occurrence is set, use today's date with the due_time
            base_date = timezone.now().replace(
                hour=self.due_time.hour,
                minute=self.due_time.minute,
                second=0,
                microsecond=0,
            )

        # Calculate next occurrence
        if self.recurrence == "daily":
            next_date = base_date + timezone.timedelta(days=1)
        elif self.recurrence == "weekly":
            next_date = base_date + timezone.timedelta(weeks=1)
        elif self.recurrence == "monthly":
            if base_date.month == 12:
                next_date = base_date.replace(year=base_date.year + 1, month=1)
            else:
                next_date = base_date.replace(month=base_date.month + 1)

        if next_date:
            # Only create next todo if it's due
            if next_date <= now:
                new_todo = Todo.objects.create(
                    title=self.title,
                    description=self.description,
                    user=self.user,
                    recurrence=self.recurrence,
                    due_time=self.due_time,
                    parent_todo=self,
                    next_occurrence=next_date,
                    completed=False,  # Ensure the new task is not completed
                )
                return new_todo
            else:
                # If not due yet, just update the next_occurrence
                self.next_occurrence = next_date
                self.save(update_fields=["next_occurrence"])

        return None
