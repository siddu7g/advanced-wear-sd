from google.cloud import pubsub_v1

project_id = "practical-cider-125402"
topic_id = "raw-sensor-data"
subscription_id = "raw-sensor-data-sub"

# Publisher
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(project_id, topic_id)

def publish_message(message: str):
    """
    Publishes a message to the raw data topic.
    """
    future = publisher.publish(topic_path, message.encode("utf-8"))
    print(f"Published message ID: {future.result()}")

# Subscriber
subscriber = pubsub_v1.SubscriberClient()
subscription_path = subscriber.subscription_path(project_id, subscription_id)

def callback(message):
    """
    Callback function triggered for each received message.
    """
    print(f"Received message: {message.data.decode('utf-8')}")
    # TODO: Add processing logic (store, ML, etc.)
    message.ack()

streaming_pull_future = None

def start_subscriber():
    """
    Starts the subscriber in a separate thread.
    """
    global streaming_pull_future
    streaming_pull_future = subscriber.subscribe(
        subscription_path,
        callback=callback
    )
    print(f"Listening for messages on {subscription_path}...")

    try:
        streaming_pull_future.result()
    except KeyboardInterrupt:
        streaming_pull_future.cancel()
        print("Subscriber stopped.")

def stop_subscriber():
    """
    Stops the subscriber if running.
    """
    if streaming_pull_future:
        streaming_pull_future.cancel()
