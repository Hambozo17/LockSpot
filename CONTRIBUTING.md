# Contributing to LockSpot

Thank you for your interest in contributing to LockSpot!

---

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Set up the development environment (see [Installation Guide](docs/INSTALLATION.md))
4. Create a new branch for your feature

---

## Development Workflow

### Branch Naming

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring

Example: `feature/add-payment-gateway`

### Commit Messages

Use clear, descriptive commit messages:

```
feat: add Google Maps integration
fix: resolve booking overlap issue
docs: update API documentation
refactor: simplify authentication flow
```

---

## Code Style

### Flutter/Dart

- Follow official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Add comments for complex logic
- Run `flutter analyze` before committing

### Python/Django

- Follow [PEP 8](https://pep8.org/) style guide
- Use type hints where appropriate
- Document functions with docstrings
- Run `flake8` for linting

---

## Pull Request Process

1. Ensure all tests pass
2. Update documentation if needed
3. Add screenshots for UI changes
4. Request review from maintainers

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring

## Screenshots (if applicable)

## Checklist
- [ ] Code follows style guidelines
- [ ] Tests pass locally
- [ ] Documentation updated
```

---

## Testing

### Flutter

```bash
flutter test
```

### Backend

```bash
cd backend
python manage.py test
```

---

## Reporting Issues

When reporting bugs, please include:

1. Steps to reproduce
2. Expected behavior
3. Actual behavior
4. Screenshots (if applicable)
5. Device/environment details

---

## Questions?

Open a GitHub issue for any questions about contributing.
