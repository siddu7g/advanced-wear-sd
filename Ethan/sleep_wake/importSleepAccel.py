import numpy as np
import pandas as pd

def import_sleep_accel(path, id):
    """
    Imports sleep data from the SleepAccel dataset for a given subject ID.

    The output data is separated into 30-second epochs, with each epoch containing
    heart rate, raw accelerometer data, and sleep stage information.

    Parameters:
    path (str): Location of the SleepAccel dataset
    id (str): Subject ID, a 7-digit number

    Returns:
    accelerometer_epochs (list of tuples): Each tuple contains three numpy arrays (x, y, z) of shape (1500,) for each epoch
    heart_rate_epochs (list of numpy arrays): Each array contains heart rate values for the corresponding epoch (N.B. length may vary)
    sleep_labels (list of int): Sleep stage labels for each epoch
    """
    # Load data files
    hr_df = pd.read_csv(path + "/heart_rate/" + id + "_heartrate.txt", header=None)
    accel_df = pd.read_csv(path + "/motion/" + id + "_acceleration.txt", header=None, delimiter=" ")
    label_df = pd.read_csv(path + "/labels/" + id + "_labeled_sleep.txt", header=None, delimiter=" ")

    hr_t = hr_df[0].to_numpy()
    hr_values = hr_df[1].to_numpy()

    accel_t = accel_df[0].to_numpy()
    accel_x = accel_df[1].to_numpy()
    accel_y = accel_df[2].to_numpy()
    accel_z = accel_df[3].to_numpy()

    label_t = label_df[0].to_numpy()
    label_values = label_df[1].to_numpy()

    # Get the start time using the later start time of accel_t or hr_t
    start_time = max(accel_t[0], hr_t[0])

    #Round the start time up to the nearest 30-second epoch
    start_time = start_time + (30 - (start_time % 30))

    # Get the end time using the earlier end time of accel_t or hr_t
    end_time = min(accel_t[-1], hr_t[-1])

    # Round the end time down to the nearest 30-second epoch
    end_time = end_time - (end_time % 30)

    # Separate data into 30-second epochs
    num_epochs = int((end_time - start_time) // 30)

    accelerometer_epochs = []
    heart_rate_epochs = []
    sleep_labels = []

    for epoch in range(num_epochs):
        epoch_start = start_time + epoch * 30
        epoch_end = epoch_start + 30

        # Get accelerometer data for this epoch
        epoch_accel_mask = (accel_t >= epoch_start) & (accel_t < epoch_end)
        epoch_accel_x = accel_x[epoch_accel_mask]
        epoch_accel_y = accel_y[epoch_accel_mask]
        epoch_accel_z = accel_z[epoch_accel_mask]

        # Get heart rate data for this epoch
        epoch_hr_mask = (hr_t >= epoch_start) & (hr_t < epoch_end)
        epoch_hr_values = hr_values[epoch_hr_mask]

        # Get the sleep label for this epoch
        epoch_label = label_values[label_t == epoch_end]

        # Discard data if truncated epoch
        if len(epoch_accel_x) < 1490 or len(epoch_hr_values) < 4:
            # print("discarding, length was ", len(epoch_accel_x), len(epoch_hr_values))
            continue

        if not (epoch_label.size > 0):
            epoch_label = -1  # Assume awake
        else:
            epoch_label = int(epoch_label[0])
        
        accelerometer_epochs.append((epoch_accel_x[0:1490], epoch_accel_y[0:1490], epoch_accel_z[0:1490]))
        heart_rate_epochs.append(epoch_hr_values)
        sleep_labels.append(epoch_label)
    return accelerometer_epochs, heart_rate_epochs, sleep_labels

if __name__ == "__main__":
    # Example usage
    path = "../Data/SleepAccel/"
    id = "8686948"  # Example subject ID
    accel_epochs, hr_epochs, sleep_labels = import_sleep_accel(path, id)
    print(f"Imported {len(accel_epochs)} epochs for subject ID {id}.")