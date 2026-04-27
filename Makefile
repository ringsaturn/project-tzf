fmt:
	autocorrect --fix content
	hugo convert toYAML config.toml --unsafe content/

server:
# 	hugo server --buildDrafts --buildFuture --gc --minify --baseURL http://localhost:1313
	hugo server --buildDrafts --buildFuture --disableFastRender --bind 0.0.0.0

# server: build-dev-public
# 	wrangler pages dev public --port 1313
