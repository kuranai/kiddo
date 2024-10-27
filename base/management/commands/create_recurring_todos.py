from django.core.management.base import BaseCommand
from django.utils import timezone

from base.models import Todo


class Command(BaseCommand):
    help = "Creates recurring todos for the next occurrence"

    def handle(self, *args, **kwargs):
        now = timezone.now()

        # Get all recurring todos that have a next_occurrence in the past
        todos = Todo.objects.filter(
            recurrence__in=["daily", "weekly", "monthly"],
            next_occurrence__lte=now,
            completed=True,
        )

        created_count = 0
        for todo in todos:
            new_todo = todo.create_next_occurrence()
            if new_todo:
                created_count += 1

        self.stdout.write(
            self.style.SUCCESS(f"Successfully created {created_count} recurring todos")
        )
