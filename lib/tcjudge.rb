#!/usr/bin/env ruby

# TopCoder Local Judge by peryaudo
# MIT License

require 'io/console'
require 'tmpdir'
require 'mechanize'

class TopCoderScraper
  def initialize(tmpdir)
    @logged_in = false
    @tmpdir = tmpdir
  end

  # return false if succeeded
  def login(user_name, password)
    if @logged_in
      return false  
    end
 
    @agent = Mechanize.new

    next_page_uri = 'https://www.topcoder.com/'
    login_page_uri = 'https://community.topcoder.com/tc?&module=Login'

    login_page = @agent.get(login_page_uri)

    top_page = login_page.form_with(:name => 'frmLogin') do |f|
      f.action = 'https://community.topcoder.com/tc'
      f['username'] = user_name
      f['password'] = password
    end.click_button

    if top_page.uri.to_s == next_page_uri
      # succeeded
      @logged_in = true
      return false 
    else
      return true
    end

  end

  def is_cache_available(problem_name, required)
    if required.include?(:problem_definition) && !File.exist?("#{ @tmpdir }/#{ problem_name }.bpd")
      return false
    end
    if required.include?(:test_cases) && !File.exist?("#{ @tmpdir }/#{ problem_name }.btestcase")
      return false
    end
    return true
  end

  def get_problem_definition(problem_name)
    cache_file_name = "#{ @tmpdir }/#{ problem_name }.bpd"

    root = nil
    if File.exist?(cache_file_name)
      return Marshal.restore(open(cache_file_name, 'rb'))

    else
      unless @logged_in
        return nil
      end

      statement_uri = get_problem_page_uri(problem_name).sub('/tc?module=ProblemDetail', '/stat?c=problem_statement')
      root = @agent.get(statement_uri).root

    end

    problem_definition = {}

    problem_definition[:points] = @agent.get(get_problem_page_uri(problem_name)). \
      root.xpath('//tr[contains(td/text(), "Point Value")]/td/text()').drop(1).map { |td| td.content.to_i }

    table = root.xpath('//table[contains(tr/td/text(), "Class:")]').first

    table.xpath('tr').each do |tr|
      td = tr.xpath('td/text()').map { |td| td.content }
      if td.length != 2
        next
      end

      case td[0]
      when 'Class:'
        problem_definition[:class_name] = td[1]
      when 'Method:'
        problem_definition[:method_name] = td[1]
      when 'Returns:'
        problem_definition[:return_type] = td[1]
      when 'Method signature:'
        td[1].match(/\((.+)\)/) do |backward|
          problem_definition[:parameters] = backward[1].split(',').map do |raw_parameter|
            parameter = raw_parameter.strip.split(' ')
            {:type => parameter[0], :name => parameter[1]}
          end
        end
      end
    end

    unless File.exist?(cache_file_name)
      Marshal.dump problem_definition, open(cache_file_name, 'wb')
    end

    return problem_definition
  end

  def get_test_cases(problem_name)
    cache_file_name = "#{ @tmpdir }/#{ problem_name }.btestcase"

    root = nil
    if File.exist?(cache_file_name)
      return Marshal.restore(open(cache_file_name, 'rb'))

    else
      unless @logged_in
        return nil
      end

      solution_uri = get_solution_page_uri(get_problem_page_uri(problem_name))

      root = @agent.get(solution_uri).root

    end

    test_cases = []

    table = root.xpath('//comment()[contains(., "System Testing")]/following-sibling::table').first

    table.xpath('tr[@valign="top"]').each do |tr|
      test_case = tr.xpath('td[@class="statText"]/text()').map { |td| td.content.gsub(/(\r|\n)/, ' ') }
      test_cases.push({:input => test_case[0], :output => test_case[1]})
    end

    unless File.exist?(cache_file_name)
      Marshal.dump test_cases, open(cache_file_name, 'wb')
    end
    return test_cases
  end

  private
  def get_problem_page_uri(problem_name)
    unless @logged_in
      return nil
    end

    unless @problem_page_uri_cache
      @problem_page_uri_cache = {}
    end

    if @problem_page_uri_cache.include?(problem_name)
      return @problem_page_uri_cache[problem_name]
    end

    @agent.get('https://community.topcoder.com/tc?module=ProblemArchive&class=' + problem_name) do |page|
      return @problem_page_uri_cache[problem_name] =
        page.root.xpath(
          '//tr[normalize-space(td/a/text())="' + problem_name +
          '"]/td/a[starts-with(@href, "/tc?module=ProblemDetail")]/@href').first.content
    end
  end

  def get_solution_page_uri(problem_page_uri)
    @agent.get(problem_page_uri) do |page|
      return page.link_with(:href => /\/stat\?c\=problem_solution.+cr=[0-9]+/).href
    end
  end
end

CompileError = Class.new(StandardError)

class TopCoderTester
  def generate_timestamp
    return "// TIMESTAMP: #{ Time.now.to_i }"
  end

  def print_points(code)
    code.match(/^\/\/ TIMESTAMP: ([0-9]+)$/) do |backward|
      seconds = Time.now.to_i - backward[1].to_i
      @problem_definition[:points].each_with_index do |total, i|
        points = convert_seconds_to_points(seconds, total)
        warn "Score: #{ sprintf('%.2f', points) } / #{ total } (#{ seconds } secs)"
      end
    end
    return
  end

  def convert_seconds_to_points(seconds, mp)
    tt = 60.0
    pt = seconds / 60.0
    return mp * (0.3 + (0.7 * tt ** 2) / (10.0 * pt ** 2 + tt **2))
  end

  def generate_signature()
    return convert_type(@problem_definition[:return_type]) + ' ' + @problem_definition[:method_name] + '(' + \
      (@problem_definition[:parameters].map { |parameter| convert_type(parameter[:type]) + ' ' + parameter[:name] }).join(', ') + ')'
  end

  # strictly parse comma separated parameters
  def split_parameters(parameters_string)

    depth = 0
    prev = 0
    start = false

    parameters = []

    parameters_string.length.times do |index|
      case parameters_string[index]
      when '"'
        if start
          depth += 1
        else
          depth -= 1
        end
        start = !start
      when '{'
        depth += 1
      when '}'
        depth -= 1
      when ','
        if depth == 0
          cur = parameters_string[prev .. (index - 1)].strip
          if !(cur.empty?)
            parameters.push(cur)
          end
          prev = index + 1
        end
      end
    end

    cur = parameters_string[prev .. parameters_string.length - 1].strip
    if !(cur.empty?)
      parameters.push(cur)
    end

    return parameters
  end

  def perform_cut(code)
    return code.split(/r?\n/).inject(['', true]) do |succ, cur|
      if cur =~ /^\/\/ CUT begin/
        [succ[0], false]
      elsif cur =~ /^^\/\/ CUT end/
        [succ[0], true]
      else
        if succ[1] == true
          [succ[0] + "\n" + cur, succ[1]]
        else
          succ
        end
      end
    end.first
  end
end

class TopCoderCXXTester < TopCoderTester
  def get_template(template_proc)
    if template_proc.nil?
      return <<EOS
#include <vector>
#include <string>
#include <map>
#include <set>
#include <algorithm>
#include <iostream>
#include <cmath>
#include <climits>
#include <queue>
#include <stack>
#include <numeric>

using namespace std;

// CUT begin
#{ generate_timestamp() }
// CUT end

class #{ @problem_definition[:class_name] } {
public:
	#{ generate_signature() } {
	}
};
EOS
    else
      return instance_eval(&template_proc)
    end
  end

  def convert_type(type_name)
    cxx_type_names = {'long' => 'long long', 'String' => 'string'}

    is_array = false
    base_type_name = type_name
    if type_name =~ /\[\]$/
      is_array = true
      base_type_name = type_name.sub(/\[\]$/, '').strip
    end

    cxx_type_name = nil
    if cxx_type_names.include?(base_type_name)
      cxx_type_name = cxx_type_names[base_type_name]
    else
      cxx_type_name = base_type_name
    end

    if is_array
      cxx_type_name = "vector<#{ cxx_type_name }>"
    end

    return cxx_type_name
  end

  def generate_tester()
    tester = <<EOS
#include <iostream>
#include <vector>
#include <string>
#include <cstdlib>
#include <cmath>

using namespace std;

#{ generate_result_comparison_function() }
#{ generate_result_dumper_function() }
#{ generate_limitter_function() }

EOS

    @test_cases.length.times do |index|
      tester += generate_tester_function(index)
    end


    tester += <<EOS
int main(int argc, char *argv[])
{
  setLimit();
  switch(atoi(argv[1])) {
EOS

  @test_cases.length.times do |index|
    tester += "    case #{ index }: return test#{ index }();\n"
  end

  tester += <<EOS
  }
}
EOS

    return tester
  end

  def generate_result_comparison_function
    cxx_type = convert_type(@problem_definition[:return_type])

    func = "bool compareResult(#{ cxx_type } from, #{ cxx_type } to)\n{\n"
    case cxx_type
    when 'double'
      func += "  return fabs(from - to) <= 1e-9;\n";
    when 'vector<double>'
      func += <<EOS
  if (from.size() != to.size()) return false;
  bool res = true;
  for (int i = 0; i < from.size(); ++i) {
    if (!(fabs(from[i] - to[i]) <= 1e-9)) {
      res = false;
      break;
    }
  }
  return res;
EOS
    else
      func += "  return from == to;\n"
    end

    func += "}\n"

    return func
  end

  def generate_result_dumper_function
    cxx_type = convert_type(@problem_definition[:return_type])

    func = "void dumpResult(#{ cxx_type } result_)\n{\n"
    if cxx_type =~ /^vector/
      func += <<EOS
  cout<<"{";
  for (int i = 0; i < result_.size(); ++i) {
    const #{cxx_type.sub(/^vector\<(.+)\>$/, '\\1')}& result = result_[i];
EOS
    else
      func += "  const #{cxx_type.sub(/^vector\<(.+)\>$/, '\\1')}& result = result_;\n"
    end

    if cxx_type == 'string' || cxx_type == 'vector<string>'
      func += '  cout<<"\""<<result<<"\"";'
      func += "\n"
    else
      func += "  cout<<result;\n"
    end

    if cxx_type =~ /^vector/
      func += <<EOS
    cout<<(i == result_.size() - 1 ? "" : ", ");
  }
  cout<<"}";
EOS
    end

    func += "}\n"

    return func
  end

  def generate_limitter_function
    return "void setLimit() {return;}\n"
  end

  def generate_tester_function(index)
    return <<EOS
int test#{ index }(void)
{
  #{ @problem_definition[:class_name] } target;
#{ generate_parameters(@test_cases[index][:input]) }
#{ generate_tester_call() }
#{ generate_parameter(@problem_definition[:return_type], "expected", @test_cases[index][:output]) }
  if (compareResult(result, expected)) {
    return 0;
  } else {
    dumpResult(result);
    return 1;
  }
}
EOS
  end

  def generate_parameters(parameters_string)
    result = ''
    parameters = split_parameters(parameters_string)

    @problem_definition[:parameters].each_with_index do |parameter, index|
      result += generate_parameter(parameter[:type], "param#{index}", parameters[index])
    end

    return result
  end

  def generate_primary_value(type, value)
    case type
    when 'String'
      return "string(#{value})"
    when 'long'
      return "#{value}LL"
    else
      return value
    end
  end

  def generate_parameter(type, name, value)
    if type =~ /\[\]$/
      # vector
      element_type = type.sub(/\[\]$/, '')
      elements = split_parameters(value[1, value.length - 2])
      parameter = "  #{ convert_type(type) } #{ name }(#{ elements.length });\n"
      elements.each_with_index do |element, index|
        parameter += "  #{ name }[#{index}] = #{ generate_primary_value(element_type, element)};\n"
      end
      return parameter
    else
      return "  #{ convert_type(type) } #{ name } = #{ generate_primary_value(type, value) };\n"
    end
  end

  def generate_tester_call
    return "  #{ convert_type(@problem_definition[:return_type]) } result = target.#{ @problem_definition[:method_name] }(" +
      (0 .. (@problem_definition[:parameters].length - 1)).map { |index| "param#{ index }" }.join(', ') + ");"
  end

  def initialize(problem_definition, test_cases = nil, tmpdir = nil, code = nil, compiler = nil)
    @problem_definition = problem_definition

    if test_cases != nil && tmpdir != nil && code != nil && compiler != nil
      @test_cases = test_cases
      @tmpdir = tmpdir

      @tester_source_name = "#{@tmpdir}/tester.cpp"
      @tester_name = "#{@tmpdir}/tester"

      open(@tester_source_name, 'w').write "#{ perform_cut(code) }\n#{ generate_tester() }"

      if File.basename(compiler, '.exe').downcase == 'cl' then
        @compile_options = "#{compiler} /Fe\"#{@tester_name}\" \"#{@tester_source_name}\""
      else
        @compile_options = "#{compiler} \"#{@tester_source_name}\" -o \"#{@tester_name}\""
      end

      unless system(@compile_options)
        raise CompileError
      end
    end
  end

  def run(index)
    tester_options = "\"#{@tester_name}\" #{index}"
    if system(tester_options)
      return :AC
    else
      case $?.exitstatus
      when 1
        return :WA
      else
        if $?.exited?
          return :UNKNOWN_ERROR
        else
          puts "\nCompiller Options: #{@compile_options}"
          puts "Tester Options: #{tester_options}"
          puts "Exit Status: #{$?}"
          return :RUNTIME_ERROR
        end
      end
    end
  end
end

class TopCoderJavaTester < TopCoderTester
  def get_template(template_proc)
    if template_proc.nil?
      return <<EOS
// CUT begin
#{ generate_timestamp() }
// CUT end
public class #{ @problem_definition[:class_name] } {
	public #{ generate_signature() } {
	}
}
EOS
    else
      return instance_eval(&template_proc)
    end
  end

  def convert_type(type_name)
    return type_name
  end

  def generate_tester()
    tester = <<EOS
public class Tester {
#{ generate_result_comparison_function() }
#{ generate_result_dumper_function() }
EOS

    @test_cases.length.times do |index|
      tester += generate_tester_function(index)
    end

    tester += <<EOS
  public static void main(String[] args) {
    switch (Integer.parseInt(args[0])) {
EOS
  @test_cases.length.times do |index|
    tester += "      case #{ index }: System.exit(test#{ index }());\n"
  end
  tester += <<EOS
    }
    return;
  }
}
EOS

    return tester
  end

  def generate_result_comparison_function
    java_type = convert_type(@problem_definition[:return_type])

    func = "static boolean compareResult(#{ java_type } from, #{ java_type } to)\n{\n"
    case java_type
    when 'double'
      func += "  return Math.abs(from - to) <= 1e-9;\n";
    when 'double[]'
      func += <<EOS
  if (from.length != to.length) return false;
  boolean res = true;
  for (int i = 0; i < from.length; ++i) {
    if (!(Math.abs(from[i] - to[i]) <= 1e-9)) {
      res = false;
      break;
    }
  }
  return res;
EOS
    else
      if java_type =~ /\[\]$/
        func += <<EOS
  if (from.length != to.length) return false;
  boolean res = true;
  for (int i = 0; i < from.length; ++i) {
    if (from[i] != to[i]) {
      res = false;
      break;
    }
  }
  return res;
EOS
      else
        func += "  return from == to;\n"
      end
    end

    func += "}\n"

    return func
  end

  def generate_result_dumper_function
    java_type = convert_type(@problem_definition[:return_type])

    func = "static void dumpResult(#{ java_type } result_)\n{\n"
    if java_type =~ /\[\]$/
      func += <<EOS
  System.out.print("{");
  for (int i = 0; i < result_.length; ++i) {
    #{ java_type.sub('[]','') } result = result_[i];
EOS
    else
      func += "  #{ java_type.sub('[]','') } result = result_;\n"
    end

    if java_type == 'string' || java_type == 'string[]'
      func += '  System.out.print("\"" + result + "\"");'
      func += "\n"
    else
      func += "  System.out.print(String.valueOf(result));\n"
    end

    if java_type =~ /\[\]$/
      func += <<EOS
    System.out.print(i == result_.length - 1 ? "" : ", ");
  }
  System.out.print("}");
EOS
    end

    func += "}\n"

    return func
  end

  def generate_tester_function(index)
    return <<EOS
static int test#{ index }()
{
  #{ @problem_definition[:class_name] } target = new #{ @problem_definition[:class_name] }();
#{ generate_parameters(@test_cases[index][:input]) }
#{ generate_tester_call() }
#{ generate_parameter(@problem_definition[:return_type], "expected", @test_cases[index][:output]) }
  if (compareResult(result, expected)) {
    return 0;
  } else {
    dumpResult(result);
    return 1;
  }
}
EOS
  end

  def generate_parameters(parameters_string)
    result = ''
    parameters = split_parameters(parameters_string)

    @problem_definition[:parameters].each_with_index do |parameter, index|
      result += generate_parameter(parameter[:type], "param#{index}", parameters[index])
    end

    return result
  end

  def generate_primary_value(type, value)
    case type
    when 'String'
      return "#{value}"
    when 'long'
      return "#{value}L"
    else
      return value
    end
  end

  def generate_parameter(type, name, value)
    if type =~ /\[\]$/
      # array
      element_type = type.sub(/\[\]$/, '')
      elements = split_parameters(value[1, value.length - 2])
      parameter = "  #{ convert_type(type) } #{ name } = { "
      parameter += elements.map { |element| generate_primary_value(element_type, element) }.join(', ')
      parameter += " };\n"
      return parameter
    else
      return "  #{ convert_type(type) } #{ name } = #{ generate_primary_value(type, value) };\n"
    end
  end

  def generate_tester_call
    return "  #{ convert_type(@problem_definition[:return_type]) } result = target.#{ @problem_definition[:method_name] }(" +
      (0 .. (@problem_definition[:parameters].length - 1)).map { |index| "param#{ index }" }.join(', ') + ");"
  end

  def initialize(problem_definition, test_cases = nil, tmpdir = nil, code = nil, compiler = nil)
    @problem_definition = problem_definition

    if test_cases != nil && tmpdir != nil && code != nil && compiler != nil
      @test_cases = test_cases
      @tmpdir = tmpdir

      @tester_source_name = "#{@tmpdir}/Tester.java"
      @solution_source_name = "#{@tmpdir}/#{@problem_definition[:class_name]}.java"

      open(@tester_source_name, 'w') {|f| f.write generate_tester() }
      open(@solution_source_name, 'w') {|f| f.write perform_cut(code) }

      @compile_options = "#{compiler} #{@solution_source_name} #{@tester_source_name}"
      puts @compile_options
      unless system(@compile_options)
        raise CompileError
      end
    end
  end

  def run(index)
    tester_options = "java -classpath \"#{@tmpdir}\" Tester #{index}"
    if system(tester_options)
      return :AC
    else
      case $?.exitstatus
      when 1
        return :WA
      else
        if $?.exited?
          return :UNKNOWN_ERROR
        else
          puts "\nCompiller Options: #{ @compile_options }"
          puts "Tester Options: #{tester_options}"
          puts "Exit Status: #{$?}"
          return :RUNTIME_ERROR
        end
      end
    end
  end

end

class TopCoderCSharpTester < TopCoderTester
  def get_template(template_proc)
    if template_proc.nil?
      return <<EOS
using System;
using System.Collections.Generic;
using System.Text;

// CUT begin
#{ generate_timestamp() }
// CUT end

public class #{ @problem_definition[:class_name] }
{
	public #{ generate_signature() }
	{
	}
}
EOS
    else
      return instance_eval(&template_proc)
    end
  end

  def convert_type(type_name)
    return type_name.sub('String', 'string')
  end

  def generate_tester()
    tester = <<EOS
public class Tester {
#{ generate_result_comparison_function() }
#{ generate_result_dumper_function() }
EOS

    @test_cases.length.times do |index|
      tester += generate_tester_function(index)
    end

    tester += <<EOS
  static int Main(string[] args) {
    switch (int.Parse(args[0])) {
EOS
  @test_cases.length.times do |index|
    tester += "      case #{ index }: return test#{ index }();\n"
  end
  tester += <<EOS
    }
    return 0;
  }
}
EOS

    return tester
  end

  def generate_result_comparison_function
    cs_type = convert_type(@problem_definition[:return_type])

    func = "static bool compareResult(#{ cs_type } from, #{ cs_type } to)\n{\n"
    case cs_type
    when 'double'
      func += "  return Math.Abs(from - to) <= 1e-9;\n";
    when 'double[]'
      func += <<EOS
  if (from.Length != to.Length) return false;
  bool res = true;
  for (int i = 0; i < from.Length; ++i) {
    if (!(Math.abs(from[i] - to[i]) <= 1e-9)) {
      res = false;
      break;
    }
  }
  return res;
EOS
    else
      if cs_type =~ /\[\]$/
        func += <<EOS
  if (from.Length != to.Length) return false;
  bool res = true;
  for (int i = 0; i < from.Length; ++i) {
    if (from[i] != to[i]) {
      res = false;
      break;
    }
  }
  return res;
EOS
      else
        func += "  return from == to;\n"
      end
    end

    func += "}\n"

    return func
  end

  def generate_result_dumper_function
    cs_type = convert_type(@problem_definition[:return_type])

    func = "static void dumpResult(#{ cs_type } result_)\n{\n"
    if cs_type =~ /\[\]$/
      func += <<EOS
  Console.Write("{");
  for (int i = 0; i < result_.length; ++i) {
    #{ cs_type.sub('[]','') } result = result_[i];
EOS
    else
      func += "  #{ cs_type.sub('[]','') } result = result_;\n"
    end

    if cs_type == 'string' || cs_type == 'string[]'
      func += '  Console.Write("\"" + result + "\"");'
      func += "\n"
    else
      func += "  Console.Write(result.ToString());\n"
    end

    if cs_type =~ /\[\]$/
      func += <<EOS
    System.out.print(i == result_.length - 1 ? "" : ", ");
  }
  System.out.print("}");
EOS
    end

    func += "}\n"

    return func
  end

  def generate_tester_function(index)
    return <<EOS
static int test#{ index }()
{
  #{ @problem_definition[:class_name] } target = new #{ @problem_definition[:class_name] }();
#{ generate_parameters(@test_cases[index][:input]) }
#{ generate_tester_call() }
#{ generate_parameter(@problem_definition[:return_type], "expected", @test_cases[index][:output]) }
  if (compareResult(result, expected)) {
    return 0;
  } else {
    dumpResult(result);
    return 1;
  }
}
EOS
  end

  def generate_parameters(parameters_string)
    result = ''
    parameters = split_parameters(parameters_string)

    @problem_definition[:parameters].each_with_index do |parameter, index|
      result += generate_parameter(parameter[:type], "param#{index}", parameters[index])
    end

    return result
  end

  def generate_primary_value(type, value)
    case type
    when 'String'
      return "#{value}"
    when 'long'
      return "#{value}L"
    else
      return value
    end
  end

  def generate_parameter(type, name, value)
    if type =~ /\[\]$/
      # array
      element_type = type.sub(/\[\]$/, '')
      elements = split_parameters(value[1, value.length - 2])
      parameter = "  #{ convert_type(type) } #{ name } = new #{ convert_type(type) } { "
      parameter += elements.map { |element| generate_primary_value(element_type, element) }.join(', ')
      parameter += " };\n"
      return parameter
    else
      return "  #{ convert_type(type) } #{ name } = #{ generate_primary_value(type, value) };\n"
    end
  end

  def generate_tester_call
    return "  #{ convert_type(@problem_definition[:return_type]) } result = target.#{ @problem_definition[:method_name] }(" +
      (0 .. (@problem_definition[:parameters].length - 1)).map { |index| "param#{ index }" }.join(', ') + ");"
  end

  def initialize(problem_definition, test_cases = nil, tmpdir = nil, code = nil, compiler = nil)
    @problem_definition = problem_definition

    if test_cases != nil && tmpdir != nil && code != nil && compiler != nil
      @test_cases = test_cases
      @tmpdir = tmpdir

      @tester_source_name = "#{@tmpdir}/tester.cs"
      @tester_name = "#{@tmpdir}/tester.exe"

      open(@tester_source_name, 'w') {|f| f.write perform_cut(code) + generate_tester() }

      @compiler = compiler
      if File.basename(compiler, '.exe').downcase == 'csc'
        @compile_options = "#{compiler} /r:System.Numerics.dll #{@tester_source_name} /out:\"#{@tester_name}\""
      else
        @compile_options = "#{compiler} /r:System.Numerics.dll #{@tester_source_name} -out:\"#{@tester_name}\""
      end
      puts @compile_options
      unless system(@compile_options)
        raise CompileError
      end
    end
  end

  def run(index)
    tester_options = nil
    if File.basename(@compiler, '.exe').downcase == 'csc'
      tester_options = "\"#{@tester_name}\" #{index}"
    else
      tester_options = "mono \"#{@tester_name}\" #{index}"
    end
    if system(tester_options)
      return :AC
    else
      case $?.exitstatus
      when 1
        return :WA
      else
        if $?.exited?
          return :UNKNOWN_ERROR
        else
          puts "\nCompiller Options: #{ @compile_options }"
          puts "Tester Options: #{tester_options}"
          puts "Exit Status: #{$?}"
          return :RUNTIME_ERROR
        end
      end
    end
  end

end

class TopCoderHaskellTester < TopCoderTester
  def generate_timestamp
    return "-- TIMESTAMP: #{ Time.now.to_i }"
  end

  def print_points(code)
    code.match(/^-- TIMESTAMP: ([0-9]+)$/) do |backward|
      seconds = Time.now.to_i - backward[1].to_i
      @problem_definition[:points].each_with_index do |total, i|
        points = convert_seconds_to_points(seconds, total)
        warn "Score: #{ sprintf('%.2f', points) } / #{ total } (#{ seconds } secs)"
      end
    end
    return
  end

  def generate_signature()
    return @problem_definition[:method_name] + ' :: ' + \
      (@problem_definition[:parameters].map { |parameter| convert_type(parameter[:type]) }).join(' -> ') + ' -> ' + convert_type(@problem_definition[:return_type])
  end


  def get_template(template_proc)
    if template_proc.nil?
      return <<EOS
-- CUT begin
#{ generate_timestamp() }
-- CUT end

#{ generate_signature() }
#{ @problem_definition[:method_name] } #{ (@problem_definition[:parameters].map { |parameter| parameter[:name] }).join(' ') } = 
EOS
    else
      return instance_eval(&template_proc)
    end
  end

  def convert_type(type_name)
    haskell_type_names = {'int' => 'Int', 'long' => 'Int', 'double' => 'Double', 'String' => 'string'}

    is_array = false
    base_type_name = type_name
    if type_name =~ /\[\]$/
      is_array = true
      base_type_name = type_name.sub(/\[\]$/, '').strip
    end

    haskell_type_name = nil
    if haskell_type_names.include?(base_type_name)
      haskell_type_name = haskell_type_names[base_type_name]
    else
      haskell_type_name = base_type_name
    end

    if is_array
      haskell_type_name = "[#{ haskell_type_name }]"
    end

    return haskell_type_name
  end

  def generate_tester()
    tester = <<EOS
#{ generate_result_comparison_function() }
#{ generate_result_dumper_function() }

EOS

    @test_cases.length.times do |index|
      tester += generate_tester_function(index)
    end


    tester += <<EOS

myExitWith 0 = exitWith (ExitSuccess)
myExitWith x = exitWith (ExitFailure x)

main = do args <- getArgs
          res <- test (read (head args))
          myExitWith res
EOS

    return tester
  end

  def generate_result_comparison_function
    haskell_type = convert_type(@problem_definition[:return_type])

    func = nil

    case haskell_type
    when 'Double'
      func = "compareResult from to = abs (from - to) <= 1e-9\n";
    when '[Double]'
      func = <<EOS
compareResult (x:xs) (y:ys) = if abs (from - to) <= 1e-9 then (compareResult xs ys) else False
compareResult [] [] = True
compareResult _ _ = False
EOS
    else
      func = "compareResult from to = from == to\n"
    end

    return func
  end

  def generate_result_dumper_function
    return "dumpResult = print"
  end

  def generate_tester_function(index)
    return <<EOS
test #{ index } = do
#{ generate_parameters(@test_cases[index][:input]) }
#{ generate_tester_call() }
#{ generate_parameter(@problem_definition[:return_type], "expected", @test_cases[index][:output]) }
  if (compareResult result expected) then
    return 0
  else 
    (dumpResult result) >> (return 1)

EOS
  end

  def generate_parameters(parameters_string)
    result = ''
    parameters = split_parameters(parameters_string)

    @problem_definition[:parameters].each_with_index do |parameter, index|
      result += generate_parameter(parameter[:type], "param#{index}", parameters[index])
    end

    return result
  end

  def generate_parameter(type, name, value)
    if type =~ /\[\]$/
      elements = split_parameters(value[1, value.length - 2])
      return "  let #{name} = [" + elements.join(', ') + "]\n"
    else
      return "  let #{name} = #{ value }\n"
    end
  end

  def generate_tester_call
    return "  let result = #{ @problem_definition[:method_name] } " +
      (0 .. (@problem_definition[:parameters].length - 1)).map { |index| "param#{ index }" }.join(' ')
  end

  def initialize(problem_definition, test_cases = nil, tmpdir = nil, code = nil, compiler = nil)
    @problem_definition = problem_definition

    if test_cases != nil && tmpdir != nil && code != nil && compiler != nil
      @test_cases = test_cases
      @tmpdir = tmpdir

      @tester_source_name = "#{@tmpdir}/tester.hs"
      @tester_name = "#{@tmpdir}/tester"

      open(@tester_source_name, 'w').write <<EOS
import System.Environment
import System.Exit

#{ perform_cut(code) }
#{ generate_tester() }
EOS

      @compile_options = "#{compiler} \"#{@tester_source_name}\" -o \"#{@tester_name}\""

      unless system(@compile_options)
        raise CompileError
      end
    end
  end

  def run(index)
    tester_options = "\"#{@tester_name}\" #{index}"
    if system(tester_options)
      return :AC
    else
      case $?.exitstatus
      when 1
        return :WA
      else
        if $?.exited?
          return :UNKNOWN_ERROR
        else
          puts "\nCompiller Options: #{@compile_options}"
          puts "Tester Options: #{tester_options}"
          puts "Exit Status: #{$?}"
          return :RUNTIME_ERROR
        end
      end
    end
  end

  def perform_cut(code)
    return code.split(/r?\n/).inject(['', true]) do |succ, cur|
      if cur =~ /^-- CUT begin/
        [succ[0], false]
      elsif cur =~ /^-- CUT end/
        [succ[0], true]
      else
        if succ[1] == true
          [succ[0] + "\n" + cur, succ[1]]
        else
          succ
        end
      end
    end.first
  end
end

class TopCoderPythonTester < TopCoderTester
  def generate_timestamp
    return "# TIMESTAMP: #{ Time.now.to_i }"
  end

  def print_points(code)
    code.match(/^# TIMESTAMP: ([0-9]+)$/) do |backward|
      seconds = Time.now.to_i - backward[1].to_i
      @problem_definition[:points].each_with_index do |total, i|
        points = convert_seconds_to_points(seconds, total)
        warn "Score: #{ sprintf('%.2f', points) } / #{ total } (#{ seconds } secs)"
      end
    end
    return
  end

  def generate_signature()
    return @problem_definition[:method_name] + '(self, ' + \
      (@problem_definition[:parameters].map { |parameter| parameter[:name] }).join(', ') + ')'
  end


  def get_template(template_proc)
    if template_proc.nil?
      return <<EOS
# -*- coding: utf-8 -*-

import math,string,itertools,fractions,heapq,collections,re,array,bisect

# CUT begin
#{ generate_timestamp() }
# CUT end

class #{ @problem_definition[:class_name] }:
    def #{ generate_signature() }:

EOS
    else
      return instance_eval(&template_proc)
    end
  end

  def convert_type(type_name)
    return type_name
  end

  def generate_tester()
    tester = <<EOS
class Tester:
#{ generate_result_comparison_function() }
#{ generate_result_dumper_function() }
EOS

    @test_cases.length.times do |index|
      tester += generate_tester_function(index)
    end

    tester += <<EOS
import sys

if __name__ == '__main__':
    tester = Tester()
    sys.exit(eval('tester.test' + sys.argv[1] + '()'))
EOS

    return tester
  end

  def generate_result_comparison_function
    func = <<EOS
    def compareResult(self, from_, to_):
EOS
    case @problem_definition[:return_type]
    when 'double'
      func += <<EOS
        return abs(from_ - to_) <= 1e-9
EOS
    when 'double[]'
      func += <<EOS
        return reduce(lambda x, y: x && (abs(y[0] - y[1]) <= 1e-9), zip(from_, to_), True)
EOS
    else
      func += <<EOS
        return from_ == to_
EOS
    end

    return func;
  end

  def generate_result_dumper_function
    return "    def dumpResult(self, result_):\n        print result_\n"
  end

  def generate_tester_function(index)
    return <<EOS
    def test#{index}(self):
        target = #{ @problem_definition[:class_name] }();
#{ generate_parameters(@test_cases[index][:input]) }
#{ generate_tester_call() }
#{ generate_parameter(@problem_definition[:return_type], "expected", @test_cases[index][:output]) }
        if self.compareResult(result, expected):
            return 0
        else:
            self.dumpResult(result)
            return 1

EOS
  end

  def generate_parameters(parameters_string)
    result = ''
    parameters = split_parameters(parameters_string)

    @problem_definition[:parameters].each_with_index do |parameter, index|
      result += generate_parameter(parameter[:type], "param#{index}", parameters[index])
    end

    return result
  end

  def generate_primary_value(type, value)
    case type
    when 'String'
      return "#{value}"
    when 'long'
      return "#{value}L"
    else
      return value
    end
  end

  def generate_parameter(type, name, value)
    if type =~ /\[\]$/
      # array
      element_type = type.sub(/\[\]$/, '')
      elements = split_parameters(value[1, value.length - 2])
      parameter = "        #{ name } = [ "
      parameter += elements.map { |element| generate_primary_value(element_type, element) }.join(', ')
      parameter += " ]\n"
      return parameter
    else
      return "        #{ name } = #{ generate_primary_value(type, value) };\n"
    end
  end

  def generate_tester_call
    return "        result = target.#{ @problem_definition[:method_name] }(" +
      (0 .. (@problem_definition[:parameters].length - 1)).map { |index| "param#{ index }" }.join(', ') + ");"
  end

  def initialize(problem_definition, test_cases = nil, tmpdir = nil, code = nil, interpreter = nil)
    @problem_definition = problem_definition

    if test_cases != nil && tmpdir != nil && code != nil && interpreter != nil
      @test_cases = test_cases
      @tmpdir = tmpdir

      @tester_source_name = "#{@tmpdir}/tester.py"

      open(@tester_source_name, 'w').write "#{ perform_cut(code) }\n#{ generate_tester() }"

      @interpreter = interpreter
    end
  end

  def run(index)
    tester_options = "#{@interpreter} #{@tester_source_name} #{index}"
    if system(tester_options)
      return :AC
    else
      case $?.exitstatus
      when 1
        return :WA
      else
        if $?.exited?
          return :UNKNOWN_ERROR
        else
          puts "\nCompiller Options: #{ @compile_options }"
          puts "Tester Options: #{tester_options}"
          puts "Exit Status: #{$?}"
          return :RUNTIME_ERROR
        end
      end
    end
  end

end

class TCJudge
  def initialize
    @languages = { :CXX => TopCoderCXXTester, :Java => TopCoderJavaTester,
                   :CSharp => TopCoderCSharpTester, :VB => nil,
                   :Python => TopCoderPythonTester, :Haskell => TopCoderHaskellTester }
    @default_compilers = { :CXX => 'g++', :Java => 'javac', :CSharp => 'mcs', :VB => 'vbc', :Python => 'python', :Haskell => 'ghc' }
    @extensions = { '.cpp' => :CXX, '.cc' => :CXX, '.cxx' => :CXX,
                   '.java' => :Java, '.cs' => :CSharp, '.vb' => :VB , '.py' => :Python, '.hs' => :Haskell }

    tcjudegrc_file_name = File.expand_path('~/.tcjudgerc')
    if File.exist?(tcjudegrc_file_name)
      instance_eval File.read(tcjudegrc_file_name)
    end
  end

  def start(argv)
    warn 'TopCoder Local Judge by peryaudo'

    filenames = []
    options = []

    argv.each do |arg|
      if arg =~ /^--/
        options.push arg
      else
        filenames.push arg
      end
    end
    
    if filenames.length != 1 && filenames.length != 2
      warn 'usage: tcjudge MyProblemSolution.cpp'
      warn "       tcjudge [command] MyProblemSolution.cpp\n"
      warn 'commands: create - create template for the problem'
      warn '          judge - judge the file'
      warn '          clean - output the cleaned code to stdout'
      return
    end

    command = nil
    filename = nil

    if filenames.length == 1
      if filenames[0] == 'solved' then
        command = 'solved'
      else
        command = 'judge'
        filename = filenames[0]
      end
    elsif filenames.length == 2
      command = filenames[0]
      filename = filenames[1]
    end

    case command
      when 'create'
        write_template filename
      when 'judge'
        judge filename, options.include?('--force')
      when 'clean'
        clean filename
        warn 'tcjudge: wrote the cleaned code to stdout'
      when 'solved'
        show_solved
      else
        warn 'tcjudge: invalid command line option'
    end
  end

  def write_template(file_name)
    if File.exist?(file_name)
      warn "tcjudge: file #{ file_name } already exists."
      return
    end

    extension = File.extname(file_name)
    unless @extensions.include?(extension)
      warn 'tcjudge: cannot detect the language'
      return
    end

    language = @languages[@extensions[extension]]

    if language.nil?
      warn 'tcjudge: the language is not supported yet'
      return
    end

    problem_name = File.basename(file_name, extension)

    scraper = TopCoderScraper.new(Dir.tmpdir)
    unless scraper.is_cache_available(problem_name, [:problem_definition])
      if login(scraper)
        return
      end
    end

    $stderr.print 'Obtaining problem definition...'
    problem_definition = nil
    begin
      problem_definition = scraper.get_problem_definition(problem_name)
    rescue
      warn "\ntcjudge: couldn't retrive the problem definition of #{ problem_name }."
      return
    end

    warn 'ok.'

    $stderr.print 'Writing template...'

    open file_name, 'w' do |destination|
      @template ||= {}
      @template[@extensions[extension]] ||= nil
      destination.write language.new(problem_definition).get_template(@template[@extensions[extension]])
      warn 'ok.'
    end
  end

  def clean(file_name)
    extension = File.extname(file_name)
    unless @extensions.include?(extension)
      warn 'tcjudge: cannot detect the language'
      return
    end

    language = @languages[@extensions[extension]]

    if language.nil?
      warn 'tcjudge: the language is not supported yet'
      return
    end

    print language.new(nil).perform_cut(open(file_name, 'r').read)
    return
  end

  def judge(file_name, force = false)
    code = nil
    begin
      open file_name, 'r' do |file|
        code = file.read
      end
    rescue
      warn "tcjudge: file #{ file_name } couldn't be opened or doesn't exist."
      return
    end

    extension = File.extname(file_name)
    unless @extensions.include?(extension)
      warn 'tcjudge: cannot detect the language'
      return
    end

    language = @languages[@extensions[extension]]

    if language.nil?
      warn 'tcjudge: the language is not supported yet'
      return
    end

    problem_name = File.basename(file_name, extension)

    scraper = TopCoderScraper.new(Dir.tmpdir)
    unless scraper.is_cache_available(problem_name, [:problem_definition, :test_cases])
      if login(scraper)
        return
      end
    end

    $stderr.print 'Obtaining problem definition...'
    problem_definition = scraper.get_problem_definition(problem_name)
    warn 'ok.'

    $stderr.print 'Obtaining testcases...'
    test_cases = scraper.get_test_cases(problem_name)
    warn " total #{ test_cases.length } cases."

    tester = nil

    begin
      @compiler ||= {}
      @compiler[@extensions[extension]] ||= @default_compilers[@extensions[extension]]
      tester = language.new(problem_definition, test_cases, Dir.tmpdir, code, @compiler[@extensions[extension]])
    rescue CompileError
      warn 'tcjudge: compile error'
      return
    end

    succeeded = true

    test_cases.length.times do |index|
      current_succeeded = true

      print "Test Case #{ index } ..."
      result = tester.run(index)
      case result
      when :AC
        puts 'Accepted.'
      when :WA
        puts 'WRONG ANSWER.'
        current_succeeded = false
      when :TLE
        puts 'TIME LIMIT EXCEEDED.'
        current_succeeded = false
      when :MLE
        puts 'MEMORY LIMIT EXCEEDED.'
        current_succeeded = false
      when :RUNTIME_ERROR
        puts 'RUNTIME ERROR.'
        current_succeeded = false
      else
        puts 'UNKNOWN ERROR.'
        current_succeeded = false
      end

      unless current_succeeded
        succeeded = false

        puts "Test Case: #{ test_cases[index][:input] }"
        puts "Expected Output: #{ test_cases[index][:output] }"
        if !force
          break
        end
      end
    end

    if succeeded
      warn 'All Tests Succeeded.'
    else
      warn 'Testing Failed.'
    end

    tester.print_points(code)

    return
  end

  # return false if succeeded
  def login(scraper)
    @user_name ||= nil
    if @user_name.nil?
      $stderr.print 'User Name: '
      @user_name = $stdin.gets().strip
    end

    @password ||= nil
    if @password.nil?
      $stderr.print 'Password: '
      @password = $stdin.noecho(&:gets).strip
    end

    unless scraper.login(@user_name, @password)
      warn "\ntcjudge: login succeeded"
      return false
    else
      warn "\ntcjudge: login failed"
      return true
    end
  end

  def show_solved
    agent = Mechanize.new

    template = {}
    @diary[:difficulties].each do |difficulty|
      template[difficulty] = false
    end

    solved = {}
    (@diary[:from_srm]..@diary[:to_srm]).each do |i|
      solved["SRM#{i}"] = template.dup
    end

    month = @diary[:from_month]
    while month <= @diary[:to_month]
      page = agent.get("#{@diary[:url]}archive/#{month.strftime('%Y%m')}")

      lis = page.root.xpath('//li[@class="archive archive-section"]')
      titles = lis.map { |li| li.content }

      titles.each do |title|
        tags = title.scan(/\[([0-9a-zA-Z]+)\]/).flatten
        srm_idx = nil
        probs = []
        tags.each do |tag|
          if tag =~ /^SRM/ then
            srm_idx = tag 
          else
            probs.push tag
          end
        end

        next unless srm_idx

        probs.each do |prob|
          solved[srm_idx] ||= template.dup
          solved[srm_idx][prob] = true
        end
      end

      month = month.next_month
    end

    sorted = solved.sort do |a, b|
      if a.first.length == b.first.length then
        a.first <=> b.first
      else
        a.first.length <=> b.first.length
      end
    end

    sorted.each do |srm|
      state = @diary[:difficulties].map { |difficulty| srm.last[difficulty] ? '*' : '-' }.join

      puts "#{srm.first} #{state}"
    end

  end
end
