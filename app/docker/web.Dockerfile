FROM nginx:1.27-alpine
COPY index.html styles.css app.js /usr/share/nginx/html/
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
EXPOSE 8080
