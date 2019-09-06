import ntplib
import time
from datetime import datetime, timedelta
import threading


class ResponseTime():
	sum_RTT = 0
	num_requests = 0
	def add(self, delay):
		self.sum_RTT += float(delay)
		self.num_requests += 1
	def avg(self):
		return self.sum_RTT / self.num_requests

class NTPResponse():
	monotonic = 0
	offset = 0
	def __init__(self, monotonic_time, monotonic_offset):
		self.monotonic = monotonic_time
		self.offset = monotonic_offset

class GoodClock():

	# def __init__(self):
	response_history = []
	sync_thread = None
	RTT_tracker = ResponseTime()

	def drift_rate(self):
		if len(self.response_history) < 2:
			return 0
		latest = self.response_history[-1]
		first = self.response_history[0]
		if (latest.monotonic - first.monotonic < 300):
			# not enough time has elapsed to accurately compute drift (< 5 minutes)
			return 0
		# return change in monotonic offset per second
		return (latest.offset - first.offset) / (latest.monotonic - first.monotonic)

	def now(self):
		if len(self.response_history) < 1:
			# could also return datetime.now() instead
			return None

		latest = self.response_history[-1]
		elapsed = time.monotonic() - latest.monotonic
		true_offset = latest.offset + elapsed * self.drift_rate()
		return datetime.fromtimestamp(time.monotonic() + true_offset)

	def run(self):
		if self.sync_thread == None:
			self.sync_thread = threading.Thread(target=self.sync)
			self.sync_thread.start()

	def sync(self):
		while True:
			
			# Send NTP request
			try:
				# print("sync attempt")

				diff1 = time.monotonic() - time.time()
				response = ntplib.NTPClient().request('time.apple.com', version=3)

				# compute offset relative to monotonic time
				monotonic_time = time.monotonic()
				monotonic_offset = time.time() + response.offset - monotonic_time

				diff2 = time.monotonic() - time.time()

				# account for race condition where system clock is corrected
				if abs(diff1 - diff2) > 0.005:
					# system clock has corrected by 5ms or more, ignore
					time.sleep(1)
					continue

				self.RTT_tracker.add(response.delay)

				if response.delay <= self.RTT_tracker.avg(): 
					# good response time, keep this bad boy
					self.response_history.append(NTPResponse(monotonic_time, monotonic_offset))
					time.sleep(1.25 ** len(self.response_history))
				else:
					# bad response time, try again in 2 seconds
					time.sleep(2)

				# Only keep the fastest requests for drift calculation
				if len(self.response_history) > 20:
					if self.response_history[0].delay > self.response_history[1].delay:
						del self.response_history[0]
					else:
						del self.response_history[1]

			except Exception as e:
				print("EXCEPTION", e)
				# try again in 6 seconds
				time.sleep(6)
				continue
	

Clock = GoodClock()
Clock.run()
while True:
	time.sleep(1)
	print('Time: ' + str(Clock.now()))

	
