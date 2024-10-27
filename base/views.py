from django.contrib.auth.mixins import LoginRequiredMixin
from django.http import JsonResponse
from django.shortcuts import get_object_or_404
from django.urls import reverse_lazy
from django.views import View
from django.views.generic import CreateView, ListView, UpdateView

from .forms import TodoForm
from .models import Todo


# Create your views here.
class TodoListView(ListView):
    model = Todo
    template_name = "list_todos.html"
    context_object_name = "todos"

    def get_queryset(self):
        return Todo.objects.filter(user=self.request.user).order_by("-created_at")


class TodoCreateView(LoginRequiredMixin, CreateView):
    model = Todo
    form_class = TodoForm
    template_name = "create_todo.html"
    success_url = reverse_lazy("todo_list")

    def form_valid(self, form):
        form.instance.user = self.request.user
        return super().form_valid(form)


class TodoUpdateView(LoginRequiredMixin, UpdateView):
    model = Todo
    template_name = "edit_todo.html"
    form_class = TodoForm
    success_url = reverse_lazy("todo_list")
    context_object_name = "todo"


class TodoToggleComplete(LoginRequiredMixin, View):
    def post(self, request, pk):
        todo = get_object_or_404(Todo, pk=pk, user=request.user)
        todo.completed = not todo.completed
        todo.save()

        # If the todo is completed and it's recurring,
        # check/update next occurrence
        if todo.completed and todo.recurrence != "none":
            todo.create_next_occurrence()

        return JsonResponse({"status": "success", "completed": todo.completed})
