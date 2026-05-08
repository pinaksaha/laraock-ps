FROM nginx:1.27-alpine

RUN apk add --no-cache bash curl tzdata

# Replace upstream nginx.conf with our own. Per-app server blocks come from
# files mounted into /etc/nginx/conf.d at runtime.
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80 443
CMD ["nginx", "-g", "daemon off;"]
