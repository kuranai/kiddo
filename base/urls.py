from django.urls import path

from .views import TodoCreateView, TodoListView, TodoToggleComplete, TodoUpdateView

urlpatterns = [
    path("todos/", TodoListView.as_view(), name="todo_list"),
    path("todos/create/", TodoCreateView.as_view(), name="create_todo"),
    path("todos/<int:pk>/edit/", TodoUpdateView.as_view(), name="edit_todo"),
    path("todos/<int:pk>/toggle/", TodoToggleComplete.as_view(), name="toggle_todo"),
]
