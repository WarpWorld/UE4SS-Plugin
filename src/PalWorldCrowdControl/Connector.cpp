#include "Connector.h"

#include <ws2tcpip.h>
#include <stdio.h>
#include <iostream>
#include <functional>
#include <chrono>
#include <memory>
#include <File/Macros.hpp>
#include <DynamicOutput/DynamicOutput.hpp> 
#include <Mod/CppUserModBase.hpp>
#include <JSON/Parser/Parser.hpp>
#include <JSON/Parser/TokenParser.hpp>
#include <JSON/Parser/Tokens.hpp>
#include <ParserBase/Token.hpp>

#pragma comment(lib, "Ws2_32.lib")


Connector::Connector()
{
	WORD wVersionRequested = MAKEWORD(2, 2);
	WSADATA wsaData = { 0 };
	int err = WSAStartup(wVersionRequested, &wsaData);
}

Connector::~Connector()
{
    Stop();
}

void Connector::Stop()
{
	if (m_socket != INVALID_SOCKET)
	{
		closesocket(m_socket);
		m_socket = INVALID_SOCKET;
	}

	WSACleanup();
}

bool Connector::HasError()
{
	return hasError;
}

const char* Connector::GetError()
{
	return (const char*)error;
}

void Connector::ResetError()
{
	hasError = false;
	ZeroMemory(&error, sizeof(error));
}

bool Connector::IsConnected()
{
	return m_socket != INVALID_SOCKET && !connecting;
}

bool Connector::IsRunning()
{
	return running && checking;
}

void Connector::OnMenu(bool isOpen)
{
	std::lock_guard guard(m_mutex);
	menuOpened = isOpen;
}

int Connector::GetItemCount()
{
	std::lock_guard guard(m_mutex);
	return command_map.size();
}

std::shared_ptr<Command> Connector::PopItem()
{
	try
	{
		std::lock_guard guard(m_mutex);
		if (command_map.size() > 0)
		{
			auto iter = command_map.begin();
			auto last = iter->second;
			command_map.erase(iter);
			return last;
		}
	}
	catch (std::exception e)
	{
		Output::send<LogLevel::Verbose>(STR("PopItem error: {}\n"));
	}

	return NULL;
}

void Connector::NewTimer(UINT command_id, int miliseconds)
{
	std::lock_guard guard(m_mutex);
	auto c = command_map[command_id];
	c->type = 2;
	if (c->duration > 0)miliseconds = c->duration;
	c->time = GetElapsedTime() + (long long)miliseconds;
	//_MESSAGE("Time: %d + %d = %d", GetElapsedTime(), (long long)miliseconds, GetElapsedTime() + (long long)miliseconds);
	timer_map.insert({ c->command, c });
}

void Connector::ExtendTimer(UINT command_id, int miliseconds)
{
	std::lock_guard guard(m_mutex);
	auto c = command_map[command_id];
	c->time += miliseconds;
}

bool Connector::HasTimer(UINT command_id)
{
	try
	{
		std::lock_guard guard(m_mutex);
		auto c = command_map[command_id];
		return HasTimer(c->command);
	}
	catch (std::exception e)
	{
		Output::send<LogLevel::Verbose>(STR("HasTimer error: {}\n"));
	}

	return false;
}

bool Connector::HasTimer(std::string command_name)
{
	return timer_map.find(command_name) != timer_map.end();
}

void Connector::ClearTimers()
{
	std::lock_guard lock(m_mutex);
	timer_map.clear();
}

void Connector::ConnectAsync(const char* port)
{
	if (IsConnected() || connecting) return;
	if (connect_thread.valid())
	{
		auto status = connect_thread.wait_for(std::chrono::milliseconds::zero());
		if (status == std::future_status::ready)
		{
			bool result = connect_thread.get();

			if (!result)
				connect_thread = std::async(&Connector::Connect, this, port);

			else
				connect_thread = std::future<bool>();
		}
	}
	else
	{
		connect_thread = std::async(&Connector::Connect, this, port);
	}
}

bool Connector::Connect(const char* port)
{
	value_lock connect_lock(&connecting, true, false);

	try
	{
		int iFamily = AF_INET;
		int iType = SOCK_STREAM;
		int iProtocol = IPPROTO_TCP;

		struct addrinfo* result = NULL,
			* ptr = NULL,
			hints;

		ZeroMemory(&hints, sizeof(hints));

		iResult = getaddrinfo("127.0.0.1", port, &hints, &result);

		if (iResult != 0)
		{
			hasError = true;
			snprintf(error, sizeof(error), "getaddrinfo error: %d", iResult);

			return false;
		}

		ptr = result;

		m_socket = socket(ptr->ai_family, ptr->ai_socktype, ptr->ai_protocol);

		if (m_socket == INVALID_SOCKET)
		{
			hasError = true;
			snprintf(error, sizeof(error), "Socket creation failed: %d", WSAGetLastError());

			return false;
		}

		iResult = connect(m_socket, ptr->ai_addr, (int)ptr->ai_addrlen);
		if (iResult == SOCKET_ERROR)
		{
			hasError = true;
			//closesocket(m_socket);

			m_socket = INVALID_SOCKET;
			snprintf(error, sizeof(error), "Error connecting to Crowd Control");

			return false;
		}

		ResetError();
		Output::send<LogLevel::Verbose>(STR("Connected to Crowd Control\n"));
		connecting = false;
		Run();

		return true;
	}
	catch (std::exception e)
	{
		Output::send<LogLevel::Verbose>(STR("Connect error: {}\n"));
		if (m_socket != INVALID_SOCKET)
		{
			closesocket(m_socket);
			m_socket = INVALID_SOCKET;
		}
	}

	return false;
}

std::wstring swap(std::string str)
{
    std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
	std::wstring command = converter.from_bytes(str);
    return command;
}


void Connector::Respond(int id, int status, std::string message, int miliseconds)
{
	try
	{
		std::shared_ptr<Command> c;
		{
			std::lock_guard lock(m_mutex);
			auto iter = command_map.find((UINT)id);
			if (iter == command_map.end())
				return;
			c = iter->second;
		}

		bool timer_created = false;
		if (status == 4)
		{
			timer_created = true;
			status = 0;
			if (!HasTimer(id))
			{
				NewTimer(id, miliseconds);
			}
			else
			{
				ExtendTimer(id, miliseconds);
			}
		}

		if (c->type == 1 || timer_created)
			Respond(id, status, message);

		std::lock_guard lock(m_mutex);
		command_map.erase(c->id);
	}
	catch (std::exception e)
	{
		Output::send<LogLevel::Verbose>(STR("Respond error timed: {}\n"));
	}
}

void Connector::Respond(int id, int status, std::string message)
{
	try
	{
        std::string buf = "{";

		buf += "\"id\":";
        buf += std::to_string(id);

		buf += ", \"status\":";
        buf += std::to_string(status);

		if (message.length() > 0)
        {
            buf += "\"message\":\"";
            buf += message;
            buf += "\"";
        }
        buf += "}";

		std::wstring msg = STR("Sending Response: ");
        msg += swap(buf);

		Output::send<LogLevel::Verbose>(msg);

		buf += '\0';

		send(m_socket, buf.c_str(), buf.length(), 0);
	}
	catch (std::exception e)
	{
		Output::send<LogLevel::Verbose>(STR("Respond error normal: {}\n"));
	}
}

void Connector::RespondVis(std::string code, int status, std::string message)
{
	try
	{
        std::string buf = "{";

		buf += "\"id\":0";
		buf += ",\"type\":1";

		buf += ",\"code\":\"";
        buf += code;
		buf += "\"";

		buf += ", \"status\":";
        buf += std::to_string(status);

		if (message.length() > 0)
        {
            buf += "\"message\":\"";
            buf += message;
            buf += "\"";
        }
        buf += "}";

		std::wstring msg = STR("Sending Response: ");
        msg += swap(buf);

		Output::send<LogLevel::Verbose>(msg);

		buf += '\0';

		send(m_socket, buf.c_str(), buf.length(), 0);
	}
	catch (std::exception e)
	{
		Output::send<LogLevel::Verbose>(STR("Respond error normal: {}\n"));
	}
}

void Connector::RespondTimed(int id, int status, std::string message, int dur)
{
	try
	{
        std::string buf = "{";

		buf += "\"id\":";
        buf += std::to_string(id);

		buf += ", \"status\":";
        buf += std::to_string(status);

		buf += ", \"duration\":";
        buf += std::to_string(dur);

		if (message.length() > 0)
        {
            buf += "\"message\":\"";
            buf += message;
            buf += "\"";
        }
        buf += "}";

		std::wstring msg = STR("Sending Response: ");
        msg += swap(buf);

		Output::send<LogLevel::Verbose>(msg);

		buf += '\0';

		send(m_socket, buf.c_str(), buf.length(), 0);
	}
	catch (std::exception e)
	{
		Output::send<LogLevel::Verbose>(STR("Respond error normal: {}\n"));
	}
}

void Connector::Run()
{
	if (!IsConnected()) return;
	if (run_thread.valid())
	{
		auto status = run_thread.wait_for(std::chrono::milliseconds::zero());

		if (status == std::future_status::ready)
		{
			run_thread = std::async(&Connector::_Run, this);
		}
	}
	else
	{
		run_thread = std::async(&Connector::_Run, this);
	}

	if (command_check_thread.valid())
	{
		auto status = command_check_thread.wait_for(std::chrono::milliseconds::zero());

		if (status == std::future_status::ready)
		{
			command_check_thread = std::async(&Connector::_RunTimer, this);
		}
	}
	else
	{
		command_check_thread = std::async(&Connector::_RunTimer, this);
	}
}

long long Connector::GetElapsedTime()
{
	return GetElapsedTime(start_time);
}

long long Connector::GetElapsedTime(std::chrono::steady_clock::time_point time)
{
	return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - time).count();
}

void Connector::_RunTimer()
{
	value_lock check_lock(&checking, true, false);
	while (true)
	{
		Sleep(500);
		try
		{
			std::lock_guard guard(m_mutex);

			long long delta_time = 0;
			if (menuOpened)
			{
				delta_time = GetElapsedTime(last_update);
			}

			long long cur_timer = GetElapsedTime();

			auto iter = command_map.begin();
			while (iter != command_map.end())
			{
				if (iter->second->type == 1 && cur_timer - iter->second->time > 2000)
				{
					Respond((int)iter->first, (int)3, "");
					iter = command_map.erase(iter);
				}
				else iter++;
			}

			auto timer_iter = timer_map.begin();
			while (timer_iter != timer_map.end())
			{
				timer_iter->second->time += delta_time;
				auto c = timer_iter->second;
				if (cur_timer > c->time)
				{
					command_map.insert({ c->id, c });
					timer_iter = timer_map.erase(timer_iter);
				}
				else timer_iter++;
			}

			last_update = std::chrono::steady_clock::now();
		}
		catch (std::exception e)
		{
			Output::send<LogLevel::Verbose>(STR("RunTimer error: {}\n"));
		}
	}
}

void replaceAll(std::string& str, const std::string& from, const std::string& to) {
    if(from.empty())
        return;
    size_t start_pos = 0;
    while((start_pos = str.find(from, start_pos)) != std::string::npos) {
        str.replace(start_pos, from.length(), to);
        start_pos += to.length();
    }
}

void replaceAll(std::wstring& str, const std::wstring& from, const std::wstring& to) {
    if(from.empty())
        return;
    size_t start_pos = 0;
    while((start_pos = str.find(from, start_pos)) != std::string::npos) {
        str.replace(start_pos, from.length(), to);
        start_pos += to.length();
    }
}

std::vector<std::string> split(std::string s, std::string delimiter) {
    size_t pos_start = 0, pos_end, delim_len = delimiter.length();
    std::string token;
    std::vector<std::string> res;

    while ((pos_end = s.find(delimiter, pos_start)) != std::string::npos) {
        token = s.substr (pos_start, pos_end - pos_start);
        pos_start = pos_end + delim_len;
        res.push_back (token);
    }

    res.push_back (s.substr (pos_start));
    return res;
}

std::string getField(std::string str, std::string field)
{
    std::string res = "";

	std::string delim = "\"";
    delim += field;
    delim += "\":";

    auto parts = split(str, delim);

	if (parts.size() < 2)
    {
        delim = field;
        delim += ":";
        parts = split(str, delim);
    }

    if (parts.size() < 2)
		return "";

	res = parts[1];

	auto parts2 = split(res, ",");
    res = parts2[0];

	replaceAll(res, "\"", "");
    return res;
}

void Connector::_Run()
{
	value_lock run_lock(&running, true, false);
	while (true)
	{
		try
		{
			ResetError();
			int last_error = 0;
			int recvbuflen = DEFAULT_BUFLEN;
			char recvbuf[DEFAULT_BUFLEN];
			ZeroMemory(&recvbuf, sizeof(recvbuf));

			iResult = recv(m_socket, recvbuf, recvbuflen, 0);
			if (iResult > 0)
			{

				// EXAMPLE: {"id":1,"code":"spawn_dragon","viewer":"sdk","type":1}\0

				auto commands = BufferSocketResponse(recvbuf, iResult);

				for (auto c : commands)
				{
					if (c.length() == 0) continue;

					//Output::send<LogLevel::Verbose>(STR("Received message"));
					//StringType msg = STR("Message: ");
                    //msg += swap(c);
					//Output::send<LogLevel::Verbose>(msg);

					std::string delim = "\"viewers\":[";
					auto parts = split(c, delim);
                    if (parts.size() > 1)
                    {
                        delim = "]";
                        auto parts2 = split(parts[1], delim);

						if (parts.size() > 1)
                        {
                            c = parts[0];
                            c += parts2[1];
                        }
                    }

					delim = "\"targets\":[";
					parts = split(c, delim);
                    if (parts.size() > 1)
                    {
                        delim = "]";
                        auto parts2 = split(parts[1], delim);

						if (parts.size() > 1)
                        {
                            c = parts[0];
                            c += parts2[1];
                        }
                    }					

					std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
					std::wstring command = converter.from_bytes(c);


					//replaceAll(command, STR(":\"\""), STR(":\"--EMPTY--\""));

					//msg = STR("Message Without Viewers: ");
                    //msg += command;
					//Output::send<LogLevel::Verbose>(msg);

					using convert_type = std::codecvt_utf8<wchar_t>;
					std::wstring_convert<convert_type, wchar_t> converter2;
					


					std::string id = getField(c, "id");
                    StringType scommand_id = swap(id);
					unsigned int command_id = std::stoi(scommand_id);

					std::string command_code = getField(c, "code");
                    StringType command_code2 = swap(command_code);

					std::string command_viewer = getField(c, "viewer");
                    StringType command_viewer2 = swap(command_code);

					std::string type = getField(c, "type");
					int command_type = std::stoi(type);

					int command_dur = 0;

					StringType msg2 = STR("Received command: ");
                    msg2 += command_code2;

					Output::send<LogLevel::Verbose>(msg2);

					try
                    {
                     	std::string dur = getField(c, "duration");
                        if (dur.length() > 0)
							command_dur = std::stoi(dur);   
                    } catch(std::exception e) { }

					Output::send<LogLevel::Verbose>(STR("Adding command to queue"));

					std::lock_guard<std::mutex> lock(m_mutex);
					command_map.insert({ command_id,
						std::make_shared<Command>(Command{
							command_id,
							command_code,
							command_viewer,
							command_type,
							GetElapsedTime(),
							command_dur
						}) });
					
				}
			}
			else if (iResult == 0)
			{
				hasError = true;
				Output::send<LogLevel::Verbose>(STR("Connection closed\n"));
				m_socket = INVALID_SOCKET;
				break;
			}

			else
			{
				last_error = WSAGetLastError();
				if (last_error != (int)WSAEWOULDBLOCK)
				{
					hasError = true;
					Output::send<LogLevel::Verbose>(STR("recv failed\n"));
					m_socket = INVALID_SOCKET;
					break;
				}
			}

		}
		catch (std::exception e)
		{
			StringType msg2 = STR("Run error: ");

			const char * s = e.what();

			std::string msg(s);

			std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
			std::wstring err = converter.from_bytes(msg);

            msg2 += err;
			//Output::send<LogLevel::Verbose>(STR("Run error\n"));
			Output::send<LogLevel::Verbose>(err);
		}
	}
}

std::vector<std::string> Connector::BufferSocketResponse(const char* buf, size_t buf_size)
{
	socketBuffer.append(buf, buf_size);
	std::vector<std::string> buffer_array;

	size_t index = socketBuffer.find('\0');
	while (index != std::string::npos)
	{
		buffer_array.push_back(socketBuffer.substr(0, index));
		socketBuffer = socketBuffer.substr(index+1);
		index = socketBuffer.find('\0');
	}

	return buffer_array;
}