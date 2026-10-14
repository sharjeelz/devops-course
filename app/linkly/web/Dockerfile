# Linkly web: nginx serving the page and forwarding /api/ and /r/ to the api container.
FROM nginx:1.27-alpine
COPY nginx.container.conf /etc/nginx/conf.d/default.conf
COPY index.html app.js style.css /usr/share/nginx/html/
EXPOSE 8080
