![image](https://github.com/Chirag0401/Zabbix-Shell-Script/assets/66375087/371bff8f-1708-4600-bc53-d87d6fef209d)
![image](https://github.com/Chirag0401/Zabbix-Shell-Script/assets/66375087/ba63e9f1-d319-4e45-b247-65a0313f69ae)
https://www.tooltester.com/en/blog/how-to-harden-your-php-for-better-security/
https://geekflare.com/apache-web-server-hardening-security/


For php.ini file
allow_url_fopen = 0: Prevents PHP from opening remote files, reducing the risk of remote code execution.

allow_url_include = 0: Disables inclusion of remote files in PHP scripts, further preventing remote code execution.

max_input_time = 30 & max_execution_time = 30: Limits the time PHP scripts take for input and execution, reducing the impact of long-running scripts that could be exploitative.

memory_limit = 8M: Restricts the amount of memory a script can use, limiting the potential damage from memory-intensive scripts.

register_globals = off: Prevents automatic global variable creation, reducing the chance of unauthorized data manipulation.

expose_php = 0: Hides PHP version info from HTTP headers, obscuring potential attack vectors.

cgi.force_redirect = 1: Ensures PHP is only executed through a web server redirect, preventing direct script execution.

post_max_size = 256K: Limits the size of POST data to reduce the risk of data flooding attacks.

max_input_vars = 100: Restricts the number of input variables, defending against attacks that overwhelm the script.

display_errors = 0 & display_startup_errors = 0: Prevents errors from being displayed to users, avoiding information leakage.

log_errors = 1: Enables logging of errors, essential for monitoring and troubleshooting.

error_log = /path/to/error_log: Specifies a path for error logging, centralizing error data for analysis.

open_basedir = "/path/to/directory": Restricts PHP file access to specified directories, preventing access to the entire filesystem.

file_uploads = 0 or 1: Disables or enables file uploads, depending on the application's need.

upload_max_filesize = 1M: Limits the maximum file size for uploads, reducing the risk from large, potentially malicious files.

upload_tmp_dir = /secure/tmp_upload/path: Sets a secure location for temporary file uploads.

Session Security Settings (like session.use_strict_mode = 1, session.cookie_httponly = 1): Enhances the security of user sessions to prevent hijacking and fixation.

disable_functions = list_of_functions: Disables specific PHP functions known to be risky, reducing the potential for their misuse.

soap.wsdl_cache_dir = /secure/dir: Sets a secure location for SOAP cache, preventing unauthorized access.





For httpd.conf file ie. apache

Remove Server Version Banner:

Change in httpd.conf: ServerTokens Prod and ServerSignature Off.
Impact: Hides Apache version and OS type, making it harder for attackers to identify potential vulnerabilities.
Disable Directory Browser Listing:

Change in httpd.conf: Set Options -Indexes or Options None in <Directory> directive.
Impact: Prevents directory listing in a browser, reducing information exposure.
Disable ETag:

Change in httpd.conf: FileETag None.
Impact: Avoids sensitive information leakage through the ETag header.
Run Apache from a Non-privileged Account:

Create a dedicated Apache user and group.
Impact: Limits the potential damage in case of a security breach.
Protect Binary and Configuration Directory Permission:

Change permissions of bin and conf folders to 750.
Impact: Restricts unauthorized access to critical directories.
System Settings Protection:

Change in httpd.conf: Set AllowOverride None in <Directory /> directive.
Impact: Prevents users from overriding Apache configuration using .htaccess.
Restrict HTTP Request Methods:

Change in httpd.conf: Add <LimitExcept GET POST HEAD> directive.
Impact: Limits allowed HTTP methods, reducing the attack surface.
Disable TRACE HTTP Request:

Change in httpd.conf: TraceEnable off.
Impact: Blocks TRACE requests, preventing Cross Site Tracing attacks.
Set Cookie with HttpOnly and Secure Flag:

Change in httpd.conf: Header edit Set-Cookie ^(.*)$ $1;HttpOnly;Secure.
Impact: Mitigates common Cross Site Scripting attacks.
Prevent Clickjacking Attack:

Change in httpd.conf: Header always append X-Frame-Options SAMEORIGIN.
Impact: Prevents clickjacking vulnerabilities.
Disable Server Side Include (SSI):

Change in httpd.conf: Add -Includes in Options directive.
Impact: Reduces server load and prevents SSI attacks.
Enable X-XSS Protection:

Change in httpd.conf: Header set X-XSS-Protection "1; mode=block".
Impact: Protects against Cross Site Scripting attacks.
Disable HTTP 1.0 Protocol:

Use mod_rewrite module to restrict to HTTP 1.1.
Impact: Mitigates session hijacking vulnerabilities associated with HTTP 1.0.
Configure Timeout Value:

Change in httpd.conf: Timeout 60.
Impact: Reduces the risk of Slow Loris attacks and DoS.
Configure SSL Settings:

Use OpenSSL for 2048-bit key, configure SSLCipherSuite, disable SSL v2 & v3.
Impact: Enhances SSL/TLS security.
Implement Mod Security:

Install Mod Security for Apache, configure rules and logging.
Impact: Adds a layer of security with a Web Application Firewall.
General Configuration:

Configure Listen directive, access logging, and disable unwanted modules.
Impact: Optimizes security by controlling access and minimizing unnecessary module exposure.
These changes collectively enhance the security of the Apache HTTP Server, reducing the risk of common vulnerabilities and attacks.
