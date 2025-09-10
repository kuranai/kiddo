# Kiddo - Family Todo & Rewards System

## Project Overview

**Kiddo** is a family-oriented todo list and rewards system designed to motivate kids with points-based rewards for completing tasks and chores. The application allows parents to create and manage todos for family members, while kids can create todos for themselves and earn points to redeem for rewards.

## Inspiration

This project is inspired by the [Family Rewards App](https://www.familyrewards.app/) and aims to replicate similar functionality with a focus on simplicity and family use. The goal is to create an internal family application with basic security that gamifies household chores and tasks.

## Core Concept

- **Users**: Family members with two roles - Parents and Kids
- **Todos**: Tasks that can be assigned and completed for points
- **Points**: Currency earned by completing todos
- **Rewards**: Items or privileges that can be "purchased" with points
- **Motivation**: Gamification encourages kids to complete tasks and learn responsibility

## Technology Stack

### Backend
- **Rails 8.0.2+** - Modern Rails with latest features
- **SQLite 3** - Simple, file-based database (2.1+)
- **Ruby 3.4.5** - Latest Ruby version

### Frontend
- **TailwindCSS 4.1.12** - Utility-first CSS framework
- **DaisyUI 5.1.9** - Beautiful component library built on Tailwind
- **Turbo & Stimulus** - Hotwire for SPA-like behavior without JavaScript frameworks
- **Importmap** - Modern JavaScript module management

### Additional Tools
- **Puma** - Web server
- **Propshaft** - Modern asset pipeline (replaces Sprockets)
- **Solid Cache** - Database-backed caching (replaces Redis)
- **Solid Queue** - Background job processing (replaces Sidekiq)
- **Solid Cable** - WebSocket functionality (replaces Redis for ActionCable)
- **Kamal** - Docker-based deployment
- **Thruster** - HTTP asset caching/compression

### Development Tools
- **RuboCop Rails Omakase** - Code style and linting
- **Brakeman** - Security analysis
- **Capybara + Selenium** - System testing

## Key Features

### User Management
- **Two User Roles**:
  - **Parents**: Can create todos for anyone, manage rewards, add family members
  - **Kids**: Can create todos for themselves, complete assigned todos, redeem rewards
- **Simple Authentication**: Email/password with bcrypt (no complex PIN system)
- **Family-Based**: Single family system (no multi-family support needed)

### Todo System
- **Todo Creation**: Parents can assign to anyone, kids to themselves only
- **Recurring Todos**: Daily, weekly, monthly recurring tasks
- **Family-Wide Todos**: Tasks anyone can claim and complete
- **Point Rewards**: Each todo has a point value awarded upon completion
- **Due Dates**: Optional due dates for todos

### Rewards System
- **Rewards Catalog**: Parents create rewards with point costs
- **Direct Redemption**: Simple point deduction system (no approval workflow)
- **Flexible Rewards**: Can be physical items, privileges, or experiences

### Points System
- **Automatic Awarding**: Points given immediately when todo is marked complete
- **Transaction History**: Full audit trail of point earnings and spending
- **Balance Tracking**: Real-time point balance for each user

### Planned Advanced Features
- **Statistics & Progress**: Charts showing completion rates and point earnings
- **Photo Uploads**: Attach photos as proof of task completion
- **Categories**: Organize todos by type (chores, homework, etc.)
- **Notifications**: Reminders for due dates
- **Family Leaderboards**: Friendly competition between family members

## Architecture

### Data Models

#### User
```ruby
# Attributes
- name: string (required, min 2 chars)
- email: string (required, unique)
- password_digest: string (bcrypt)
- role: integer (enum: kid: 0, parent: 1)
- points_balance: integer (default: 0)

# Key Methods
- can_create_todos_for?(user)
- can_manage_rewards?
- can_redeem_reward?(reward)
- add_points(amount, description)
- deduct_points(amount, description)
```

#### Todo (Planned)
```ruby
# Attributes
- title: string
- description: text
- points: integer
- assignee_id: integer (User)
- creator_id: integer (User)
- due_date: datetime
- completed: boolean
- completed_at: datetime
- recurring: boolean
- recurring_type: integer (daily/weekly/monthly)
- family_wide: boolean

# Key Methods
- completable_by?(user)
- complete!(user)
- overdue?
- generate_next_occurrence
```

#### Reward (Planned)
```ruby
# Attributes
- name: string
- description: text
- point_cost: integer
- active: boolean

# Key Methods
- affordable_by?(user)
- redeem_for!(user)
```

#### PointTransaction (Planned)
```ruby
# Attributes
- user: references
- amount: integer (positive for earning, negative for spending)
- description: string
- todo: references (optional)
- reward: references (optional)
- transaction_type: integer (earning/spending)

# Scopes
- earnings
- spendings
- recent
```

### Controllers

#### ApplicationController
- Authentication helpers (`current_user`, `logged_in?`, `require_login`)
- Authorization base functionality

#### SessionsController
- Login/logout functionality
- Redirect logic based on user role

#### UsersController
- User registration (parents can add family members)
- User profiles and management
- Family member listing

#### DashboardController
- Main landing page after login
- Family overview (for parents)
- Personal stats and quick actions

### Views & UI

#### Design System
- **DaisyUI Components**: Cards, buttons, forms, navigation, stats
- **Responsive Design**: Mobile-first approach
- **Color Scheme**: Primary colors with role-based badges
- **Typography**: Clean, readable fonts suitable for all ages

#### Key Views
- **Login Page**: Beautiful centered form with family account creation
- **Dashboard**: Role-based dashboard with family overview and quick actions
- **User Management**: Add family members, view profiles
- **Navigation**: Responsive navbar with user dropdown

## Development Status

### ✅ Phase 1: Authentication & User Management (COMPLETE)
- [x] User model with authentication and roles
- [x] Session management (login/logout)
- [x] User registration and family member management
- [x] Beautiful DaisyUI interface
- [x] Role-based authorization
- [x] Responsive navigation and layout

### 🚧 Phase 2: Core Data Models (NEXT)
- [ ] Todo model with associations and validations
- [ ] Reward model
- [ ] PointTransaction model for audit trail
- [ ] Database relationships and constraints

### 📋 Phase 3: Controllers & Routes (PLANNED)
- [ ] TodosController with CRUD operations
- [ ] RewardsController with management/redemption
- [ ] Authorization logic for todo/reward access
- [ ] API-like actions for completing todos

### ⚙️ Phase 4: Background Jobs & Recurring Tasks (PLANNED)
- [ ] Solid Queue job for recurring todo generation
- [ ] Point transaction service
- [ ] Notification system

### 🎨 Phase 5: Views & UI Enhancement (PLANNED)
- [ ] Todo management interface
- [ ] Rewards catalog
- [ ] Point transaction history
- [ ] Enhanced dashboard with statistics

### 🚀 Phase 6: Advanced Features (PLANNED)
- [ ] Photo uploads for task completion
- [ ] Statistics and progress charts
- [ ] Family leaderboards
- [ ] Push notifications

## Configuration

### Environment Setup
- **Ruby Version**: 3.4.5
- **Rails Version**: 8.0.2+
- **Database**: SQLite 3 (file-based, perfect for family use)
- **CSS Framework**: Tailwind 4.1.12 with DaisyUI 5.1.9

### Key Files
- `Gemfile` - Dependencies including bcrypt for authentication
- `config/routes.rb` - RESTful routes for authentication and user management
- `app/models/user.rb` - Core User model with roles and authentication
- `app/controllers/application_controller.rb` - Authentication helpers
- `TODO.md` - Detailed implementation roadmap
- `PROJECT.md` - This comprehensive project overview

### Database Schema
```sql
# Current Schema (Phase 1)
users:
  - id (primary key)
  - name (string, not null)
  - email (string, not null, unique)
  - password_digest (string, not null)
  - role (integer, default: 0, not null) # 0=kid, 1=parent
  - points_balance (integer, default: 0, not null)
  - created_at, updated_at

# Planned Schema Extensions (Phase 2+)
todos:
  - id, title, description, points, assignee_id, creator_id
  - due_date, completed, completed_at, recurring, recurring_type
  - family_wide, created_at, updated_at

rewards:
  - id, name, description, point_cost, active
  - created_at, updated_at

point_transactions:
  - id, user_id, amount, description, todo_id, reward_id
  - transaction_type, created_at, updated_at
```

## Security Considerations

### Authentication
- **bcrypt** for password hashing
- **Session-based** authentication (simple and secure)
- **CSRF protection** enabled by default in Rails
- **Parameter filtering** to prevent mass assignment

### Authorization
- **Role-based access**: Parents vs Kids permissions
- **Resource ownership**: Users can only access appropriate resources
- **Input validation**: Strong validations on all models

### General Security
- **Brakeman** security scanning in development
- **Modern browser requirements** for security features
- **No external dependencies** for core functionality (reduces attack surface)

## Deployment

### Current Setup
- **Kamal** for Docker-based deployment
- **Thruster** for HTTP acceleration and caching
- **SQLite** database (simple, no external database server needed)

### Production Considerations
- Environment variables for secrets
- Asset compilation with Propshaft
- Background job processing with Solid Queue
- Database backups (SQLite file backup)

## Development Workflow

### Running the Application
```bash
# Install dependencies
bundle install

# Setup database
bin/rails db:prepare

# Build CSS
bin/rails tailwindcss:build

# Start development server
bin/rails server
# or
bin/dev (includes CSS watching)
```

### Testing
```bash
# Run all tests
bin/rails test

# Run specific tests
bin/rails test test/models/user_test.rb

# System tests
bin/rails test:system
```

### Code Quality
```bash
# Lint code
bin/rubocop

# Security scan
bin/brakeman
```

## Future Enhancements

### Short Term (Phase 2-3)
- Complete core todo and rewards functionality
- Point transaction system
- Basic recurring todos

### Medium Term (Phase 4-5)
- Enhanced UI with better statistics
- Photo upload capabilities
- Push notifications for due dates

### Long Term (Phase 6+)
- Mobile app (React Native or Flutter)
- Integration with calendar systems
- Advanced reporting and analytics
- Multi-family support (if needed)

## Project Philosophy

### Simplicity First
- **Family-focused**: Designed for internal family use, not enterprise
- **Simple authentication**: No complex PIN systems or multi-tenant architecture
- **Direct workflows**: Minimal approval processes, immediate gratification

### Modern Rails
- **Rails 8 features**: Leverage Solid Queue, Solid Cache, Solid Cable
- **No unnecessary complexity**: Avoid external dependencies where Rails provides solutions
- **Progressive enhancement**: Start simple, add features incrementally

### User Experience
- **Kid-friendly**: Interface suitable for children of various ages
- **Parent control**: Parents have oversight and management capabilities
- **Mobile-responsive**: Works well on phones and tablets

---

**Project Started**: September 9, 2025  
**Current Status**: Phase 1 Complete - Authentication system ready  
**Next Milestone**: Phase 2 - Core Data Models (Todos, Rewards, Points)  
**Repository**: `/home/ploi/code/ruby/kiddo`  
**Running Instance**: http://127.0.0.1:3000