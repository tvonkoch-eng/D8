# Backend Branching Strategy for D8

## 🚀 Overview

This document outlines the branching strategy for the D8 backend to safely test changes without affecting production.

## 📋 Current Setup

### Branches
- **`main`**: Production-ready code (deployed to Railway production)
- **`development`**: Development and testing code (deployed to Railway development)

### Environments
- **Production**: `https://your-production-railway-url.railway.app`
- **Development**: `https://your-dev-railway-url.railway.app`
- **Local**: `http://localhost:8000`

## 🔧 Setup Instructions

### 1. Create Development Railway Service

1. Go to [Railway Dashboard](https://railway.app/dashboard)
2. Create a new service:
   - **Name**: `d8-backend-dev`
   - **Source**: GitHub repository `D8`
   - **Branch**: `development`
   - **Root Directory**: `Backend`

### 2. Configure Environment Variables

#### Development Service Variables:
```
ENVIRONMENT=development
OPENAI_API_KEY=your_openai_key
PORT=8000
```

#### Production Service Variables:
```
ENVIRONMENT=production
OPENAI_API_KEY=your_openai_key
PORT=8000
```

### 3. Update iOS App Configuration

The iOS app now automatically switches environments:
- **Debug builds**: Use development backend
- **Release builds**: Use production backend

Update `BackendConfiguration.swift` with your actual Railway URLs:

```swift
static var baseURL: String {
    switch current {
    case .production:
        return "https://your-production-railway-url.railway.app"
    case .development:
        return "https://your-dev-railway-url.railway.app"
    case .local:
        return "http://localhost:8000"
    }
}
```

## 🔄 Development Workflow

### Making Changes

1. **Switch to development branch**:
   ```bash
   cd Backend
   git checkout development
   ```

2. **Make your changes** to the backend code

3. **Test locally** (optional):
   ```bash
   python main.py
   ```

4. **Commit changes**:
   ```bash
   git add .
   git commit -m "Your change description"
   git push origin development
   ```

5. **Railway automatically deploys** the development branch to your dev service

6. **Test with iOS app** - it will automatically use the development backend

### Promoting to Production

1. **Merge development to main**:
   ```bash
   git checkout main
   git merge development
   git push origin main
   ```

2. **Railway automatically deploys** main branch to production

3. **Verify production** is working correctly

## 🛠️ Advanced Features

### Environment-Specific Features

The backend now supports environment-specific behavior:

- **Development**: Enhanced logging, debug information
- **Production**: Optimized performance, minimal logging

### Local Development

For local testing:

1. **Set environment**:
   ```bash
   export ENVIRONMENT=development
   ```

2. **Run locally**:
   ```bash
   python main.py
   ```

3. **iOS app** will automatically detect local environment

## 📊 Monitoring

### Development Environment
- Enhanced logging and debug information
- Detailed error messages
- Environment info in API responses

### Production Environment
- Optimized performance
- Minimal logging
- Clean API responses

## 🚨 Best Practices

1. **Always test in development first**
2. **Use descriptive commit messages**
3. **Keep development branch up to date**
4. **Monitor both environments**
5. **Use feature branches for major changes**

## 🔍 Troubleshooting

### Common Issues

1. **Environment not switching**: Check `BackendConfiguration.swift` URLs
2. **Deployment fails**: Check Railway logs and environment variables
3. **API errors**: Verify environment variables are set correctly

### Debug Commands

```bash
# Check current branch
git branch

# Check environment variables
railway variables

# View deployment logs
railway logs
```

## 📈 Next Steps

1. Set up your development Railway service
2. Update the URLs in `BackendConfiguration.swift`
3. Test the development workflow
4. Consider adding automated testing
5. Set up monitoring and alerts
