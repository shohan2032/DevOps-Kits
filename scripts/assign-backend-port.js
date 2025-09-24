const fs = require("fs");
const path = require("path");
const { exec } = require("child_process");

// file path will be ~/scripts/frontend-port-map.txt
const FRONTEND_MAP_FILE = path.join(
  "/home/ubuntu",
  "scripts",
  "frontend-port-map.txt"
);
const BACKEND_MAP_FILE = path.join(
  "/home/ubuntu",
  "scripts",
  "backend-port-map.txt"
);
const DEFAULT_BACKEND_PORT = 3333;
const DEFAULT_FRONTEND_PORT = 3000;

// Function to find a port by subdomain in the frontend map
function findFrontendPort(subdomain) {
  console.log(`Searching for frontend port for subdomain: ${subdomain}`);
  if (
    fs.existsSync(FRONTEND_MAP_FILE) &&
    fs.statSync(FRONTEND_MAP_FILE).size > 0
  ) {
    const data = fs.readFileSync(FRONTEND_MAP_FILE, "utf8");
    const lines = data.split("\n").filter(Boolean);

    for (let line of lines) {
      const [port, mappedSubdomain] = line.split(" ");
      const parsedPort = parseInt(port, 10);
      if (!isNaN(parsedPort) && mappedSubdomain === subdomain) {
        console.log(
          `Found existing frontend port ${parsedPort} for subdomain ${subdomain}`
        );
        return parsedPort;
      }
    }
  }
  return DEFAULT_FRONTEND_PORT;
}

// Function to get the next available port, starting from 3000 if file is empty
function getNextAvailablePort(file) {
  console.log(`Getting next available port from file: ${file}`);
  if (!fs.existsSync(file) || fs.statSync(file).size === 0) {
    console.log(
      "File is empty or does not exist, returning starting port 3000"
    );
    return DEFAULT_BACKEND_PORT;
  }

  const data = fs.readFileSync(file, "utf8");
  const ports = data
    .split("\n")
    .filter(Boolean)
    .map((line) => parseInt(line.split(" ")[0], 10));
  const lastPort = Math.max(...ports);

  console.log(
    `Last used port: ${lastPort}. Next available port: ${lastPort + 1}`
  );
  return lastPort + 1;
}

// Function to find a backend port by subdomain
function findBackendPort(subdomain) {
  console.log(`Searching for backend port for subdomain: ${subdomain}`);
  if (
    fs.existsSync(BACKEND_MAP_FILE) &&
    fs.statSync(BACKEND_MAP_FILE).size > 0
  ) {
    const data = fs.readFileSync(BACKEND_MAP_FILE, "utf8");
    const lines = data.split("\n").filter(Boolean);

    for (let line of lines) {
      const [port, mappedSubdomain] = line.split(" ");
      const parsedPort = parseInt(port, 10);
      if (!isNaN(parsedPort) && mappedSubdomain === subdomain) {
        console.log(
          `Found existing backend port ${parsedPort} for subdomain ${subdomain}`
        );
        return parsedPort;
      }
    }
  }
  return null;
}

// Function to check if a port is already in use in the frontend map
function isPortInUse(port) {
  console.log(`Checking if port ${port} is in use`);
  if (fs.existsSync(FRONTEND_MAP_FILE)) {
    const data = fs.readFileSync(FRONTEND_MAP_FILE, "utf8");
    const inUse = data.split("\n").some((line) => line.startsWith(`${port} `));
    if (inUse) {
      console.log(`Port ${port} is already in use.`);
    }
    return inUse;
  }
  return false;
}

// Create nginx config
function createNginxConfig(subdomain = "main") {
  const fPort = findFrontendPort(subdomain);
  const bPort = findBackendPort(subdomain);
  const builderPort = findFrontendPort("builder");
  console.log(
    `Creating NGINX config for subdomain: ${subdomain} on frontend port: ${fPort} and backend port: ${bPort}`
  );
  const fileName = `${subdomain}.ecstaging.org`;
  const isBuilderTest = ["builder-test.ecstaging.org"].includes(fileName);
  const mapConfig = isBuilderTest
    ? `map $version $proxy_target {
  1       http://localhost:${fPort};
  2       http://127.0.0.1:${builderPort};
  default http://localhost:${fPort};
}
`
    : ``;

  const proxyTarget = isBuilderTest
    ? `location ^~ /_next/ {
    proxy_pass http://localhost:${fPort};
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location / {
    auth_request /auth;
    auth_request_set $version $upstream_http_x_version;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_pass $proxy_target;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Accept-Encoding "";
    proxy_set_header Proxy "";
    proxy_cache_bypass $http_upgrade;
  }

  location = /auth {
    internal;
    proxy_pass http://localhost:${bPort}/tma/auth/check-version?host=$host&uri=https://$host$request_uri;
    proxy_pass_request_body on;
    proxy_set_header Content-Length "";
    proxy_set_header X-Original-URI $request_uri;
  }
`
    : `location / {
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_pass http://localhost:${fPort}/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Accept-Encoding "";
    proxy_set_header Proxy "";
    proxy_cache_bypass $http_upgrade;
  }
`;
  const nginxConfigContent = `${mapConfig}server {
  listen 80;
 
  server_name ${fileName};

  ${proxyTarget}


  location /api/ {
    rewrite ^/api/(.*) /$1 break;
    proxy_pass http://localhost:${bPort}/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Accept-Encoding "";
    proxy_set_header Proxy "";
    proxy_cache_bypass $http_upgrade;
  }

  location /ezy-scorm-files/ {
    proxy_pass https://ezyscorm.b-cdn.net/;
    proxy_http_version 1.1;
    proxy_set_header Host  "ezyscorm.b-cdn.net";
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_cache_bypass $http_upgrade;
    proxy_ignore_headers "Cache-Control" "Expires";
  }
}
`;

  try {
    console.log(
      `Writing NGINX config to /etc/nginx/sites-available/${fileName}`
    );
    fs.writeFileSync(
      `/etc/nginx/sites-available/${fileName}`,
      nginxConfigContent
    );
  } catch (err) {
    console.error("Error writing NGINX config:", err);
    process.exit(1);
  }

  // Creating symbolic link
  const sitesEnabledLocation = `/etc/nginx/sites-enabled/`;
  exec(
    `sudo ln -s /etc/nginx/sites-available/${fileName} ${sitesEnabledLocation}`,
    function callback(err, stdout, stderr) {
      if (err) {
        if (stderr.includes("File exists")) {
          console.warn(
            `Symbolic link ${
              sitesEnabledLocation + fileName
            } already exists. Skipping creation.`
          );
        } else {
          console.error("Error creating symbolic link:", err, stderr);
          process.exit(1);
        }
      } else {
        console.log("Symbolic link created:", stdout);
      }
    }
  );

  // Check if nginx config is valid
  exec("sudo nginx -t", function callback(err, stdout, stderr) {
    if (err) {
      console.error("NGINX config test failed:", err, stderr);
      process.exit(1);
    }
    console.log("NGINX config test passed:", stdout);
  });

  // Reload nginx
  exec("sudo systemctl reload nginx", function callback(err, stdout, stderr) {
    if (err) {
      console.error("Error reloading NGINX:", err, stderr);
      process.exit(1);
    }
    console.log("NGINX reloaded:", stdout);
  });
}

/**
 * Convert a string to a slug.
 *
 * @param {string} text - The string to convert.
 * @param {string} replacement - "-" or "_"
 * @returns {string} The slug.
 */
function slugify(text = "", replacement = "-") {
  console.log(`Slugify text: ${text} with replacement: ${replacement}`);
  if (!text) return "";
  return text
    .toString() // Convert to string
    .toLowerCase() // Convert to lowercase
    .trim() // Remove leading/trailing whitespace
    .replace(/\//g, replacement) // Replace slashes with the specified replacement
    .replace(/[^a-z0-9 -_]/g, "") // Remove all non-alphanumeric characters except hyphens and underscores
    .replace(/\s+/g, replacement) // Replace spaces with the specified replacement
    .replace(/-+/g, replacement) // Replace multiple hyphens with a single replacement
    .replace(/^-+|-+$/g, ""); // Remove hyphens from the beginning and end of the string
}

function preparePm2Config(name, path, port = 3333) {
  const pm2Config = {
    apps: [
      {
        name: name,
        script: "server.js",
        cwd: path,
        instances: "1",
        exec_mode: "cluster",
        autorestart: true,
        max_memory_restart: "1000M",
        env: {
          PORT: port,
        },
      },
    ],
  };

  fs.writeFileSync(
    path + "/ecosystem.config.js",
    `module.exports = ${JSON.stringify(pm2Config)}`
  );
}

// Main function
function main() {
  const subdomain = slugify(process.argv[2] || "");
  if (!subdomain) {
    console.error("Subdomain is empty.");
    process.exit(1);
  }

  console.log(`Processed subdomain: ${subdomain}`);
  const assignedPort = assignBackendPort(subdomain);

  console.log(
    `Assigned backend port: ${assignedPort} to subdomain: ${subdomain}`
  );

  const releasePath = `/home/ubuntu/backend/releases/${subdomain}`;
  const pm2Name = `api-${subdomain}`;

  preparePm2Config(pm2Name, releasePath, assignedPort);

  createNginxConfig(subdomain);

  console.log("Script completed successfully.");

  return {
    frontendPort: findFrontendPort(subdomain),
    backendPort: assignedPort,
    subdomain: subdomain,
  };
}

console.log(main());

function assignBackendPort(subdomain) {
  console.log(`Assigning backend port for subdomain: ${subdomain}`);
  const existingPort = findBackendPort(subdomain);
  if (existingPort) {
    console.log(
      `Subdomain ${subdomain} is already assigned to port ${existingPort}`
    );
    return existingPort;
  }

  let newPort = getNextAvailablePort(BACKEND_MAP_FILE);

  // Ensure the new port is not already in use
  while (isPortInUse(newPort)) {
    console.log(`Port ${newPort} is in use, trying next port...`);
    newPort++;
  }

  console.log(
    `Assigning new backend port ${newPort} to subdomain ${subdomain}`
  );
  fs.appendFileSync(BACKEND_MAP_FILE, `${newPort} ${subdomain}\n`, "utf8");

  return newPort;
}
