# Add "./script/semaphore.sh" step in Semaphore's Build Settings for project and set Semaphore env vars PRIVATE_GEMS_UN and PRIVATE_GEMS_PASS
bundle config https://gems.500px.net/ $PRIVATE_GEMS_UN:$PRIVATE_GEMS_PASS
