# Templates Directory

This directory previously contained model configuration templates.

**As of v3.0**, model configurations are no longer shipped with the installer.
They are fetched securely from the Izzi API server at install time via the
`/v1/provision` endpoint.

This ensures:
- Model IDs and pricing are never exposed in the public repository
- Configurations are always up-to-date
- Only authenticated users with valid API keys can access them

## For manual configuration

If you need to manually configure the Izzi provider, use these minimal settings:

```json
{
  "baseUrl": "https://api.izziapi.com",
  "api": "openai-completions",
  "apiKey": "YOUR_IZZI_API_KEY",
  "models": [
    { "id": "auto", "name": "Smart Router (Auto)" }
  ]
}
```

The `auto` model will automatically route to the best available model
for your plan. Run the installer to get the full model list.
