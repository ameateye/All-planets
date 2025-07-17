-- All Planet Start - Data Stage
-- Basic setup and custom event registration for the mod

-- Register custom event for post-initialization communication
data:extend{{
    type = "custom-event",
    name = "aps-post-init"
}}