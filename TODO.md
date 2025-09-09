# Family Todo/Rewards App - Implementation Plan

## Project Overview
A simplified family todo list and rewards system where kids and parents can create todos, earn points, and redeem rewards. Built with Rails 8.0, TailwindCSS, and DaisyUI.

## Core Features
- ✅ Basic user authentication (parent/kid roles)
- ✅ Todo creation and assignment
- ✅ Point system for completed todos
- ✅ Rewards catalog and redemption
- ✅ Recurring todos
- ✅ Family-wide todos (claimable by anyone)
- ✅ Simple dashboard and mobile-friendly UI

---

## Phase 1: Authentication & User Management

### 1.1 Set up Authentication
- [ ] Add `bcrypt` gem to Gemfile
- [ ] Generate User model with authentication fields
- [ ] Add user roles: `:parent` and `:kid`
- [ ] Create authentication controller (sessions)
- [ ] Create user registration/login views with DaisyUI
- [ ] Add before_action filters for authentication

### 1.2 User Model Setup
- [ ] User attributes: `name:string`, `email:string`, `password_digest:string`, `role:integer`, `points_balance:integer`
- [ ] User model validations and enums
- [ ] Add helper methods: `parent?`, `kid?`, `can_create_todos_for?(user)`

---

## Phase 2: Core Data Models

### 2.1 Todo Model
- [ ] Generate Todo model
- [ ] Todo attributes: `title:string`, `description:text`, `points:integer`, `assignee_id:integer`, `creator_id:integer`, `due_date:datetime`, `completed:boolean`, `completed_at:datetime`
- [ ] Add associations: `belongs_to :assignee, class_name: 'User'`, `belongs_to :creator, class_name: 'User'`
- [ ] Add validations and scopes
- [ ] Add methods: `completable_by?(user)`, `complete!`, `overdue?`

### 2.2 Recurring Todos
- [ ] Add recurring fields to Todo: `recurring:boolean`, `recurring_type:integer` (daily/weekly/monthly), `recurring_days:text`
- [ ] Create RecurringTodo model for template management
- [ ] Set up Solid Queue job for creating recurring todos
- [ ] Add logic to generate new todos based on recurring templates

### 2.3 Reward Model
- [ ] Generate Reward model
- [ ] Reward attributes: `name:string`, `description:text`, `point_cost:integer`, `active:boolean`
- [ ] Add validations
- [ ] Add methods: `affordable_by?(user)`, `redeem_for!(user)`

### 2.4 Point Transaction Model
- [ ] Generate PointTransaction model
- [ ] PointTransaction attributes: `user:references`, `amount:integer`, `description:string`, `todo:references`, `reward:references`, `transaction_type:integer`
- [ ] Add associations and validations
- [ ] Add scopes: `earnings`, `spendings`, `recent`

---

## Phase 3: Controllers & Routes

### 3.1 Authentication Controllers
- [ ] Create SessionsController (login/logout)
- [ ] Create UsersController (registration for parents only)
- [ ] Set up authentication routes
- [ ] Add redirect logic after login (parent vs kid dashboards)

### 3.2 Todo Controllers
- [ ] Create TodosController with CRUD actions
- [ ] Add authorization: parents can create for anyone, kids only for themselves
- [ ] Add complete action for marking todos done
- [ ] Add claim action for family-wide todos
- [ ] Add filters: my_todos, family_todos, completed, pending

### 3.3 Reward Controllers
- [ ] Create RewardsController (parents can CRUD, kids can view/redeem)
- [ ] Add redeem action with point deduction
- [ ] Add authorization logic

### 3.4 Dashboard Controller
- [ ] Create DashboardController
- [ ] Parent dashboard: family overview, create todos, manage rewards
- [ ] Kid dashboard: my todos, my points, available rewards

---

## Phase 4: Background Jobs & Recurring Tasks

### 4.1 Recurring Todo Job
- [ ] Create RecurringTodoJob using Solid Queue
- [ ] Job logic: find due recurring todos, create new instances
- [ ] Schedule job to run daily
- [ ] Add job monitoring and error handling

### 4.2 Point Management
- [ ] Create PointTransactionService
- [ ] Auto-award points when todo is completed
- [ ] Deduct points when reward is redeemed
- [ ] Update user point balances atomically

---

## Phase 5: Views & UI with DaisyUI

### 5.1 Layout & Navigation
- [ ] Create application layout with DaisyUI components
- [ ] Add navigation bar with user info and logout
- [ ] Add responsive design for mobile/desktop
- [ ] Create flash message styling

### 5.2 Authentication Views
- [ ] Login form with DaisyUI styling
- [ ] User registration form (parents only)
- [ ] Add form validation styling

### 5.3 Dashboard Views
- [ ] Parent dashboard: stats cards, quick actions, family activity
- [ ] Kid dashboard: my todos, points balance, reward gallery
- [ ] Add point balance display in header

### 5.4 Todo Views
- [ ] Todo index with filtering (all/mine/completed)
- [ ] Todo form (new/edit) with DaisyUI components
- [ ] Todo cards with complete buttons
- [ ] Recurring todo indicators
- [ ] Family todo badges

### 5.5 Reward Views
- [ ] Rewards catalog grid layout
- [ ] Reward cards with point costs
- [ ] Redeem buttons with confirmation modals
- [ ] Reward management for parents

---

## Phase 6: Advanced Features

### 6.1 Family-wide Todos
- [ ] Add `family_wide:boolean` to Todo model
- [ ] Add claiming logic (first come, first served)
- [ ] Show claimed status and claimer name
- [ ] Add claim/unclaim actions

### 6.2 Todo Categories & Tags
- [ ] Add optional categories (chores, homework, etc.)
- [ ] Add color coding for different categories
- [ ] Add filtering by category

### 6.3 Statistics & Progress
- [ ] Add stats to dashboards: weekly points, completion rates
- [ ] Create simple charts with Chart.js or similar
- [ ] Add leaderboard for family members

### 6.4 Photo Uploads (Optional)
- [ ] Add Active Storage for photo uploads
- [ ] Allow photos as proof of completion
- [ ] Add photo gallery for completed todos

---

## Phase 7: Testing & Polish

### 7.1 Testing
- [ ] Write model tests for all core models
- [ ] Write controller tests for main actions
- [ ] Write system tests for key user flows
- [ ] Test authorization logic thoroughly

### 7.2 Seeds & Sample Data
- [ ] Create db/seeds.rb with sample family data
- [ ] Add sample todos and rewards
- [ ] Create test users (1 parent, 2 kids)

### 7.3 Polish & UX
- [ ] Add loading states for async actions
- [ ] Add confirmation dialogs for important actions
- [ ] Add keyboard shortcuts for common actions
- [ ] Add mobile-specific optimizations

---

## Deployment Preparation

### 8.1 Production Setup
- [ ] Configure production database
- [ ] Set up Solid Queue in production
- [ ] Add proper logging
- [ ] Set up basic monitoring

### 8.2 Security Review
- [ ] Run Brakeman security scan
- [ ] Review authorization logic
- [ ] Add rate limiting if needed
- [ ] Secure sensitive routes

---

## Implementation Notes

### Technology Stack
- **Backend**: Rails 8.0.2+, SQLite 3
- **Frontend**: TailwindCSS, DaisyUI, Turbo, Stimulus
- **Jobs**: Solid Queue
- **Authentication**: Custom with bcrypt (keeping it simple)
- **Deployment**: Kamal (already configured)

### Key Design Decisions
- Single family system (no invitations needed)
- Simple role-based authorization
- Direct point redemption (no approval workflow)
- SQLite for simplicity
- Mobile-first responsive design

### Development Order
1. Start with basic authentication and user management
2. Build core todo functionality
3. Add point system and rewards
4. Implement recurring todos
5. Polish UI and add advanced features
6. Add testing and deployment prep

---

## Progress Tracking
- [ ] Phase 1: Authentication & User Management
- [ ] Phase 2: Core Data Models  
- [ ] Phase 3: Controllers & Routes
- [ ] Phase 4: Background Jobs & Recurring Tasks
- [ ] Phase 5: Views & UI with DaisyUI
- [ ] Phase 6: Advanced Features
- [ ] Phase 7: Testing & Polish
- [ ] Phase 8: Deployment Preparation

**Started**: [Date]
**Target Completion**: [Date]
**Status**: Planning Complete ✅

---

## Next Steps
1. Add bcrypt gem to Gemfile
2. Generate User model with authentication
3. Create basic authentication system
4. Build out core models (Todo, Reward, PointTransaction)

*This document will be updated as features are implemented and requirements evolve.*