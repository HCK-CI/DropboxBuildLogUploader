# DropboxBuildLogUploader

This tool will let you upload Jenkins artifacts into dropbox remote folder and update the url inside github status check, follow the steps below to deploy it:
1. Place the dropbox_uploader.rb file inside AutoHCK folder.
2. Add a new freestyle project to jenkins.
3. Mark 'This project is parameterized' checkbox and add a string value by name 'ghprbActualCommit'
4. Mark 'Restrict where this project can run' checkbox and add 'linux_host'.
5. Add build step: 'Copy artifacts from another project'
6. Set Project name: 'VirtIO', Which build: 'Upstream build that triggered this job', artifacts to copy: build_log.txt, diff.txt, sign_log.txt
. Add build step: 'Execute shell'
7. Set in the command to run, `ruby <path_to_dropbox_uploader.rb> <github_ripo> ${ghprbActualCommit} ${WORKSPACE}`
   for example : 'ruby /Prometheus/AutoHCK/dropbox_uploader.rb daynix/kvm-guest-drivers-windows ${ghprbActualCommit} ${WORKSPACE}'
8. Save changes
9. In 'VirtIO' project configuration add 'Trigger parameterized build on other projects' in Post-build action
10. In 'Projects to build' add the new project we made.
11. Set Trigger when build is 'Complete (always trigger)'
12. Click 'Add Parameters' and select 'Current bulid parameters'
13. Save changes
